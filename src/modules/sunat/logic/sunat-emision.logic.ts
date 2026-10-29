import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  ApisPeruFallo,
  ApisPeruService,
} from '../../../integrations/apisperu/apisperu.service';
import { mapListResult } from '../../../common/helpers/auth-response.helper';
import { NotificacionesLogic } from '../../notificaciones/logic/notificaciones.logic';
import { BandejaSunatDto } from '../dto/sunat.dto';
import { RutasNotificacion } from '../../notificaciones/constants/rutas-notificacion';
import type { SeveridadNotificacion } from '../../notificaciones/constants/canales';
import {
  CODIGO_TIPO_DOC,
  EstadoSunat,
  FormaEnvio,
  TipoComprobante,
} from '../constants/sunat';
import {
  construirFactura,
  numeroSunat,
  type EmisorSunat,
} from '../helpers/documentos';
import {
  CODIGO_YA_REGISTRADO,
  interpretarComprobante,
  type Interpretacion,
} from '../helpers/respuestas';
import {
  SunatComprobantesModel,
  type ComprobanteEstado,
} from '../models/sunat-comprobantes.model';
import { SunatLotesModel } from '../models/sunat-lotes.model';
import {
  SunatArchivosLogic,
  TIPO_ARCHIVO,
  type ArchivoSunat,
} from './sunat-archivos.logic';
import { SunatConfiguracionLogic } from './sunat-configuracion.logic';

const MOTIVO_NO_ENVIABLE: Partial<Record<number, string>> = {
  [EstadoSunat.NO_APLICA]: 'La nota de venta no se envía a SUNAT',
  [EstadoSunat.ACEPTADO]: 'El comprobante ya fue aceptado por SUNAT',
  [EstadoSunat.RECHAZADO]:
    'SUNAT rechazó este comprobante: su número ya no se puede reutilizar, reemita la venta',
  [EstadoSunat.ANULADO]: 'El comprobante está anulado',
  [EstadoSunat.EN_PROCESO]:
    'El comprobante ya se está enviando o está en un resumen en proceso',
};

/** Nombre base de los archivos: 20123456789-03-B001-15. */
export const nombreArchivo = (ruc: string, c: ComprobanteEstado) =>
  `${ruc}-${CODIGO_TIPO_DOC[c.tipoComprobante]}-${c.serie}-${numeroSunat(c.correlativo)}`;

/** Envío individual de boletas y facturas, consulta del CDR y descargas. */
@Injectable()
export class SunatEmisionLogic {
  private readonly logger = new Logger(SunatEmisionLogic.name);

  constructor(
    private readonly model: SunatComprobantesModel,
    private readonly lotes: SunatLotesModel,
    private readonly configuracion: SunatConfiguracionLogic,
    private readonly apisPeru: ApisPeruService,
    private readonly archivos: SunatArchivosLogic,
    private readonly notificaciones: NotificacionesLogic,
  ) {}

  async estado(id: number, idEmpresa?: number | null) {
    const c = await this.requerido(id, idEmpresa);
    return this.vista(c);
  }

  async bandeja(filtro: BandejaSunatDto, idEmpresa: number | null) {
    return mapListResult(
      await this.model.bandeja(
        {
          estadoSunat: filtro.estado_sunat,
          tipoComprobante: filtro.tipo_comprobante,
          limite: filtro.limite ?? 10,
          offset: filtro.offset,
        },
        idEmpresa,
      ),
      filtro,
    );
  }

  async historial(id: number, idEmpresa?: number | null) {
    await this.requerido(id, idEmpresa);
    return this.model.historial(id);
  }

  /**
   * Envía el comprobante y guarda la respuesta. Si APIsPERU o SUNAT no lo procesan
   * (caída, excepción 0100–1999) queda pendiente para reintentar; un rechazo
   * (2000–3999) es definitivo y obliga a reemitir.
   */
  async enviar(id: number, usuario: number | null, idEmpresa?: number | null) {
    const c = await this.enviable(id, idEmpresa);
    const { emisor, token } = await this.configuracion.contexto(c.idEmpresa);
    if (!(await this.model.reservarEnvio(id)))
      throw new ConflictException(MOTIVO_NO_ENVIABLE[EstadoSunat.EN_PROCESO]);

    let documento: object;
    try {
      documento = construirFactura(c, emisor);
    } catch (error) {
      await this.model.guardarResultado(id, {
        estadoSunat: EstadoSunat.PENDIENTE,
        mensaje: (error as Error).message,
      });
      throw new BadRequestException((error as Error).message);
    }

    try {
      const respuesta = await this.apisPeru.enviarFactura(token, documento);
      let resultado = interpretarComprobante(respuesta.sunatResponse);
      if (
        resultado.codigo === CODIGO_YA_REGISTRADO &&
        c.tipoComprobante === TipoComprobante.FACTURA
      )
        resultado = (await this.consultarCdr(token, emisor, c)) ?? resultado;
      await this.guardar(c, emisor, resultado, {
        xml: respuesta.xml,
        hash: respuesta.hash,
      });
      await this.model.bitacora({
        idComprobante: id,
        operacion: 'ENVIO',
        exito: resultado.estado === EstadoSunat.ACEPTADO,
        codigo: resultado.codigo,
        mensaje: resultado.mensaje,
        respuesta: {
          hash: respuesta.hash,
          success: respuesta.sunatResponse?.success,
          error: respuesta.sunatResponse?.error,
          cdrResponse: respuesta.sunatResponse?.cdrResponse,
        },
        usuario,
      });
      if (resultado.estado === EstadoSunat.RECHAZADO)
        await this.avisar(
          c,
          'Comprobante rechazado por SUNAT',
          `${c.serie}-${c.correlativo}: ${resultado.mensaje ?? 'sin detalle'}. Reemita la venta.`,
          'error',
        );
    } catch (error) {
      if (!(error instanceof ApisPeruFallo)) {
        await this.model.guardarResultado(id, {
          estadoSunat: EstadoSunat.PENDIENTE,
          mensaje: 'Error inesperado al enviar; se reintentará',
        });
        throw error;
      }
      await this.model.guardarResultado(id, {
        estadoSunat: EstadoSunat.PENDIENTE,
        mensaje: error.message,
      });
      await this.model.bitacora({
        idComprobante: id,
        operacion: 'ENVIO',
        exito: false,
        codigo: error.status ? `HTTP ${error.status}` : 'RED',
        mensaje: error.message,
        respuesta: error.detalle,
        usuario,
      });
      throw error.reintentable
        ? new ServiceUnavailableException(error.message)
        : new BadRequestException(error.message);
    }
    return this.estado(id);
  }

  /** Consulta el CDR en SUNAT (solo facturas: SUNAT no expone el de boletas). */
  async consultar(id: number, usuario: number, idEmpresa?: number | null) {
    const c = await this.requerido(id, idEmpresa);
    if (c.tipoComprobante !== TipoComprobante.FACTURA)
      throw new BadRequestException(
        'SUNAT solo permite consultar el CDR de facturas; las boletas se confirman con su envío o resumen',
      );
    const { emisor, token } = await this.configuracion.contexto(c.idEmpresa);
    const resultado = await this.consultarCdr(token, emisor, c);
    if (!resultado)
      throw new NotFoundException('SUNAT no tiene CDR de esta factura');
    await this.model.bitacora({
      idComprobante: id,
      operacion: 'CONSULTA_CDR',
      exito: resultado.estado === EstadoSunat.ACEPTADO,
      codigo: resultado.codigo,
      mensaje: resultado.mensaje,
      usuario,
    });
    // Una factura anulada localmente conserva su estado; solo se completa el CDR.
    if (c.estadoSunat !== EstadoSunat.ANULADO)
      await this.guardar(c, emisor, resultado, {});
    return this.estado(id);
  }

  async xml(id: number, idEmpresa?: number | null): Promise<ArchivoSunat> {
    const c = await this.requerido(id, idEmpresa);
    const { emisor, token } = await this.archivoContexto(c);
    const nombre = `${nombreArchivo(emisor.ruc, c)}.xml`;
    if (c.rutaXml)
      return this.archivos.leer(c.rutaXml, nombre, TIPO_ARCHIVO.xml);
    // Boletas del resumen diario: SUNAT no recibe su XML; se genera el firmado para el cliente.
    const xml = await this.traducir(() =>
      this.apisPeru.xmlFactura(token, construirFactura(c, emisor)),
    );
    if (c.estadoSunat === EstadoSunat.ACEPTADO) {
      const ruta = await this.archivos.guardar(
        `sunat/${emisor.ruc}/xml/${nombre}`,
        xml,
        TIPO_ARCHIVO.xml,
      );
      if (ruta) await this.model.guardarRuta(id, 'XML', ruta);
    }
    return {
      nombre,
      contenido: Buffer.from(xml, 'utf8'),
      tipo: TIPO_ARCHIVO.xml,
    };
  }

  async cdr(id: number, idEmpresa?: number | null): Promise<ArchivoSunat> {
    const c = await this.requerido(id, idEmpresa);
    const emisor = await this.model.emisor(c.idEmpresa);
    const nombre = `R-${nombreArchivo(emisor?.ruc ?? '', c)}.zip`;
    if (c.rutaCdr)
      return this.archivos.leer(c.rutaCdr, nombre, TIPO_ARCHIVO.zip);
    if (c.formaEnvio === FormaEnvio.RESUMEN) {
      const lote = await this.lotes.cdrDeComprobante(id);
      if (lote)
        return this.archivos.leer(
          lote.ruta_cdr,
          `R-${lote.identificador}.zip`,
          TIPO_ARCHIVO.zip,
        );
    }
    throw new NotFoundException('El comprobante aún no tiene CDR de SUNAT');
  }

  /** PDF A4 generado por APIsPERU; se archiva cuando el comprobante ya fue aceptado. */
  async pdfA4(id: number, idEmpresa?: number | null): Promise<ArchivoSunat> {
    const c = await this.requerido(id, idEmpresa);
    const { emisor, token } = await this.archivoContexto(c);
    const nombre = `${nombreArchivo(emisor.ruc, c)}.pdf`;
    if (c.rutaPdfA4)
      return this.archivos.leer(c.rutaPdfA4, nombre, TIPO_ARCHIVO.pdf);
    const pdf = await this.traducir(() =>
      this.apisPeru.pdfFactura(token, construirFactura(c, emisor)),
    );
    if (c.estadoSunat === EstadoSunat.ACEPTADO) {
      const ruta = await this.archivos.guardar(
        `sunat/${emisor.ruc}/pdf/${nombre}`,
        pdf,
        TIPO_ARCHIVO.pdf,
      );
      if (ruta) await this.model.guardarRuta(id, 'PDF_A4', ruta);
    }
    return { nombre, contenido: pdf, tipo: TIPO_ARCHIVO.pdf };
  }

  /** Aviso en el canal de ventas; un fallo de notificación no afecta al envío. */
  async avisar(
    c: Pick<ComprobanteEstado, 'id' | 'idPedido'> | null,
    titulo: string,
    mensaje: string,
    severidad: SeveridadNotificacion,
  ) {
    try {
      await this.notificaciones.emitir({
        canal: 'ventas',
        titulo,
        mensaje,
        severidad,
        ruta: c ? RutasNotificacion.venta(c.idPedido) : '/ventas',
        idReferencia: c?.id ?? null,
      });
    } catch (error) {
      this.logger.warn(
        `No se notificó «${titulo}»: ${(error as Error).message}`,
      );
    }
  }

  private async consultarCdr(
    token: string,
    emisor: EmisorSunat,
    c: ComprobanteEstado,
  ): Promise<Interpretacion | null> {
    const estado = await this.traducir(() =>
      this.apisPeru.estadoFactura(token, {
        tipo: CODIGO_TIPO_DOC[c.tipoComprobante],
        serie: c.serie,
        numero: numeroSunat(c.correlativo),
        ruc: emisor.ruc,
      }),
    );
    if (!estado?.cdrResponse) return null;
    return interpretarComprobante(estado);
  }

  private async guardar(
    c: ComprobanteEstado,
    emisor: EmisorSunat,
    r: Interpretacion,
    extra: { xml?: string; hash?: string },
  ) {
    const base = nombreArchivo(emisor.ruc, c);
    // Un comprobante que SUNAT no procesó no deja XML: el próximo envío genera otro.
    const procesado = r.estado !== EstadoSunat.PENDIENTE;
    const rutaXml =
      procesado && extra.xml
        ? await this.archivos.guardar(
            `sunat/${emisor.ruc}/xml/${base}.xml`,
            extra.xml,
            TIPO_ARCHIVO.xml,
          )
        : null;
    const rutaCdr = r.cdrZip
      ? await this.archivos.guardar(
          `sunat/${emisor.ruc}/cdr/R-${base}.zip`,
          Buffer.from(r.cdrZip, 'base64'),
          TIPO_ARCHIVO.zip,
        )
      : null;
    await this.model.guardarResultado(c.id, {
      estadoSunat: r.estado,
      codigo: r.codigo,
      mensaje: r.mensaje,
      observaciones: r.observaciones,
      hash: procesado ? (extra.hash ?? null) : null,
      rutaXml,
      rutaCdr,
    });
  }

  private async enviable(id: number, idEmpresa?: number | null) {
    const c = await this.requerido(id, idEmpresa);
    if (
      c.tipoComprobante !== TipoComprobante.BOLETA &&
      c.tipoComprobante !== TipoComprobante.FACTURA
    )
      throw new BadRequestException(MOTIVO_NO_ENVIABLE[EstadoSunat.NO_APLICA]);
    if (c.estadoSunat !== EstadoSunat.PENDIENTE)
      throw new BadRequestException(
        MOTIVO_NO_ENVIABLE[c.estadoSunat] ??
          'El comprobante no está pendiente de envío',
      );
    if (c.estado !== 1)
      throw new BadRequestException(
        'El comprobante fue reemplazado al reemitir la venta',
      );
    return c;
  }

  private async archivoContexto(c: ComprobanteEstado) {
    if (
      c.tipoComprobante !== TipoComprobante.BOLETA &&
      c.tipoComprobante !== TipoComprobante.FACTURA
    )
      throw new BadRequestException(MOTIVO_NO_ENVIABLE[EstadoSunat.NO_APLICA]);
    return this.configuracion.contexto(c.idEmpresa);
  }

  private async requerido(id: number, idEmpresa?: number | null) {
    const c = await this.model.comprobante(id, idEmpresa);
    if (!c) throw new NotFoundException('El comprobante no existe');
    return c;
  }

  private async traducir<T>(operacion: () => Promise<T>) {
    try {
      return await operacion();
    } catch (error) {
      if (error instanceof ApisPeruFallo)
        throw error.reintentable
          ? new ServiceUnavailableException(error.message)
          : new BadRequestException(error.message);
      throw error;
    }
  }

  private vista(c: ComprobanteEstado) {
    return {
      id: c.id,
      idPedido: c.idPedido,
      tipoComprobante: c.tipoComprobante,
      numero: `${c.serie}-${c.correlativo}`,
      estado: c.estado,
      estadoSunat: c.estadoSunat,
      formaEnvio: c.formaEnvio,
      codigoRespuesta: c.codigoRespuesta,
      mensaje: c.mensaje,
      observaciones: c.observaciones,
      hash: c.hash,
      fechaEmision: c.fechaEmision,
      fechaLimiteEnvio: c.fechaLimiteEnvio,
      fechaEnvio: c.fechaEnvio,
      intentos: c.intentos,
      montoTotal: c.montoTotal,
      tieneXml: Boolean(c.rutaXml),
      tieneCdr: Boolean(c.rutaCdr),
      tienePdfA4: Boolean(c.rutaPdfA4),
    };
  }
}
