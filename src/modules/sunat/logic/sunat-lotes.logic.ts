import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  ApisPeruFallo,
  ApisPeruService,
} from '../../../integrations/apisperu/apisperu.service';
import {
  DIAS_MAXIMOS_BAJA,
  EstadoItem,
  EstadoSunat,
  MAX_ITEMS_RESUMEN,
  TipoComprobante,
  TipoLote,
} from '../constants/sunat';
import {
  construirBaja,
  construirResumen,
  diaLima,
  type ItemLote,
} from '../helpers/documentos';
import { mapListResult } from '../../../common/helpers/auth-response.helper';
import { FiltroLotesDto } from '../dto/sunat.dto';
import { interpretarTicket } from '../helpers/respuestas';
import { SunatComprobantesModel } from '../models/sunat-comprobantes.model';
import {
  SunatLotesModel,
  type LoteCreado,
  type LoteEnProceso,
} from '../models/sunat-lotes.model';
import {
  SunatArchivosLogic,
  TIPO_ARCHIVO,
  type ArchivoSunat,
} from './sunat-archivos.logic';
import { SunatConfiguracionLogic } from './sunat-configuracion.logic';
import { SunatEmisionLogic } from './sunat-emision.logic';

const NOMBRE_TIPO: Record<number, string> = { 1: 'Boleta', 2: 'Factura' };
const NOMBRE_ESTADO: Record<number, string> = {
  0: 'No se envía',
  1: 'Pendiente',
  2: 'Aceptado',
  3: 'Rechazado',
  4: 'Anulado',
  5: 'En proceso',
};

const trozos = <T>(lista: T[], tamano: number) =>
  Array.from({ length: Math.ceil(lista.length / tamano) }, (_, i) =>
    lista.slice(i * tamano, (i + 1) * tamano),
  );

/**
 * Resumen diario de boletas (RC), comunicación de baja de facturas (RA) y el
 * envío masivo de un día. SUNAT los procesa en diferido: devuelve un ticket y la
 * respuesta llega al consultarlo (lo hace el programador o el botón «Consultar»).
 */
@Injectable()
export class SunatLotesLogic {
  private readonly logger = new Logger(SunatLotesLogic.name);

  constructor(
    private readonly model: SunatLotesModel,
    private readonly comprobantes: SunatComprobantesModel,
    private readonly configuracion: SunatConfiguracionLogic,
    private readonly emision: SunatEmisionLogic,
    private readonly apisPeru: ApisPeruService,
    private readonly archivos: SunatArchivosLogic,
  ) {}

  /** Comprobantes de un día agrupados por tipo y estado, para la pantalla del resumen. */
  async resumenDia(dia = diaLima(new Date()), idEmpresa: number | null) {
    const registros = await this.comprobantes.delDia(dia, idEmpresa);
    const grupos = [TipoComprobante.BOLETA, TipoComprobante.FACTURA].map(
      (tipo) => {
        const delTipo = registros.filter((r) => r.tipoComprobante === tipo);
        const porEstado = Object.entries(
          delTipo.reduce<Record<number, { cantidad: number; monto: number }>>(
            (acc, r) => {
              const e = (acc[r.estadoSunat] ??= { cantidad: 0, monto: 0 });
              e.cantidad += 1;
              e.monto = Math.round((e.monto + r.montoTotal) * 100) / 100;
              return acc;
            },
            {},
          ),
        ).map(([estado, v]) => ({
          estadoSunat: Number(estado),
          nombreEstado: NOMBRE_ESTADO[Number(estado)] ?? estado,
          ...v,
        }));
        return {
          tipoComprobante: tipo,
          nombreTipo: NOMBRE_TIPO[tipo],
          cantidad: delTipo.length,
          pendientes: delTipo.filter(
            (r) => r.estado === 1 && r.estadoSunat === EstadoSunat.PENDIENTE,
          ).length,
          porEstado,
        };
      },
    );
    return { fecha: dia, grupos, comprobantes: registros };
  }

  /**
   * Envío masivo del día: las facturas una por una (SUNAT no las admite en resumen)
   * y las boletas en resúmenes diarios de hasta 500.
   */
  async enviarDia(dia: string, usuario: number | null, idEmpresa: number | null) {
    await this.configuracion.contexto(idEmpresa);
    const pendientes = (await this.comprobantes.delDia(dia, idEmpresa)).filter(
      (r) => r.estado === 1 && r.estadoSunat === EstadoSunat.PENDIENTE,
    );
    const facturas = pendientes.filter(
      (r) => r.tipoComprobante === TipoComprobante.FACTURA,
    );
    const boletas = pendientes.filter(
      (r) => r.tipoComprobante === TipoComprobante.BOLETA,
    );

    const resultadoFacturas = {
      enviadas: 0,
      aceptadas: 0,
      rechazadas: 0,
      errores: [] as string[],
    };
    for (const f of facturas) {
      try {
        const r = await this.emision.enviar(f.id, usuario, idEmpresa);
        resultadoFacturas.enviadas += 1;
        if (r.estadoSunat === EstadoSunat.ACEPTADO)
          resultadoFacturas.aceptadas += 1;
        if (r.estadoSunat === EstadoSunat.RECHAZADO)
          resultadoFacturas.rechazadas += 1;
      } catch (error) {
        resultadoFacturas.errores.push(
          `${f.numero}: ${(error as Error).message}`,
        );
      }
    }

    const resumenes: unknown[] = [];
    for (const grupo of trozos(boletas, MAX_ITEMS_RESUMEN)) {
      try {
        resumenes.push(
          await this.enviarLote(
            TipoLote.RESUMEN,
            dia,
            grupo.map((b) => ({
              idComprobante: b.id,
              estadoItem: EstadoItem.ADICIONAR,
            })),
            usuario,
            idEmpresa,
          ),
        );
      } catch (error) {
        resumenes.push({
          error: (error as Error).message,
          cantidad: grupo.length,
        });
      }
    }
    return {
      fecha: dia,
      facturas: { total: facturas.length, ...resultadoFacturas },
      boletas: { total: boletas.length, resumenes },
    };
  }

  /** Boletas pendientes de un día en resumen diario (programador o envío masivo). */
  enviarBoletas(
    dia: string,
    ids: number[],
    usuario: number | null,
    idEmpresa: number | null,
  ) {
    return Promise.all(
      trozos(ids, MAX_ITEMS_RESUMEN).map((grupo) =>
        this.enviarLote(
          TipoLote.RESUMEN,
          dia,
          grupo.map((id) => ({
            idComprobante: id,
            estadoItem: EstadoItem.ADICIONAR,
          })),
          usuario,
          idEmpresa,
        ),
      ),
    );
  }

  /**
   * Da de baja en SUNAT comprobantes ya aceptados: facturas por comunicación de
   * baja (RA) y boletas por resumen diario con estado 3. Solo hasta 7 días después
   * de emitidos; pasado ese plazo corresponde una nota de crédito.
   */
  async darDeBaja(
    ids: number[],
    motivo: string,
    usuario: number | null,
    idEmpresa: number | null,
  ) {
    const lista = await this.comprobantes.comprobantes(ids, idEmpresa);
    if (!lista.length) throw new NotFoundException('El comprobante no existe');
    const hoy = diaLima(new Date());
    for (const c of lista) {
      if (c.estadoSunat !== EstadoSunat.ACEPTADO)
        throw new BadRequestException(
          `${c.serie}-${c.correlativo}: solo se da de baja un comprobante aceptado por SUNAT`,
        );
      const dias =
        (Date.parse(`${hoy}T00:00:00Z`) -
          Date.parse(`${diaLima(c.fechaEmision)}T00:00:00Z`)) /
        86_400_000;
      if (dias > DIAS_MAXIMOS_BAJA)
        throw new BadRequestException(
          `${c.serie}-${c.correlativo}: pasaron más de ${DIAS_MAXIMOS_BAJA} días, requiere nota de crédito`,
        );
    }
    const grupos = new Map<string, ItemLote[]>();
    for (const c of lista) {
      const clave = `${c.tipoComprobante}|${diaLima(c.fechaEmision)}`;
      grupos.set(clave, [
        ...(grupos.get(clave) ?? []),
        { comprobante: c, estadoItem: EstadoItem.ANULAR, motivo },
      ]);
    }
    const lotes: unknown[] = [];
    for (const [clave, items] of grupos) {
      const [tipo, dia] = clave.split('|');
      lotes.push(
        await this.enviarLote(
          Number(tipo) === TipoComprobante.FACTURA
            ? TipoLote.BAJA
            : TipoLote.RESUMEN,
          dia,
          items.map((i) => ({
            idComprobante: i.comprobante.id,
            estadoItem: EstadoItem.ANULAR,
            motivo,
          })),
          usuario,
          idEmpresa,
        ),
      );
    }
    return lotes;
  }

  /** Comprobante vigente del pedido antes de reemitir: si ya fue aceptado necesitará baja. */
  comprobanteVigente(idPedido: number) {
    return this.comprobantes.vigenteDelPedido(idPedido);
  }

  /**
   * Tras reemitir: el comprobante anterior que SUNAT ya había aceptado se da de baja en
   * segundo plano. Si falla, se avisa para hacerlo a mano desde Ventas (la reemisión
   * ya quedó hecha).
   */
  bajaPorReemision(
    anterior: { id: number; idEmpresa: number; estadoSunat: number } | null,
    usuario: number,
  ) {
    if (anterior?.estadoSunat !== EstadoSunat.ACEPTADO) return;
    void this.darDeBaja(
      [anterior.id],
      'REEMISION DEL COMPROBANTE',
      usuario,
      anterior.idEmpresa,
    ).catch(async (error: Error) => {
      const [c] = await this.comprobantes
        .comprobantes([anterior.id], anterior.idEmpresa)
        .catch(() => []);
      await this.emision.avisar(
        c ?? null,
        'Baja SUNAT pendiente',
        `No se pudo dar de baja ${c ? `${c.serie}-${c.correlativo}` : 'el comprobante reemitido'}: ${error.message}. Envíe la baja desde Ventas.`,
        'error',
      );
    });
  }

  /** Consulta los tickets pendientes (todos o uno). */
  async consultarPendientes(soloId?: number, idEmpresa?: number | null) {
    const lotes = await this.model.enProceso(soloId, idEmpresa);
    for (const lote of lotes) {
      try {
        await this.consultarLote(lote);
      } catch (error) {
        this.logger.warn(
          `No se consultó el ticket de ${lote.identificador}: ${(error as Error).message}`,
        );
        if (soloId) throw error;
      }
    }
    return lotes.length;
  }

  async consultar(id: number, idEmpresa: number | null) {
    const lote = await this.model.obtener(id, idEmpresa);
    if (!lote) throw new NotFoundException('El lote no existe');
    if (lote.estadoSunat === EstadoSunat.EN_PROCESO && lote.ticket)
      await this.consultarPendientes(id, idEmpresa);
    return this.obtener(id, idEmpresa);
  }

  async obtener(id: number, idEmpresa?: number | null) {
    const lote = await this.model.obtener(id, idEmpresa);
    if (!lote) throw new NotFoundException('El lote no existe');
    return lote.registro;
  }

  async listar(filtro: FiltroLotesDto, idEmpresa: number | null) {
    return mapListResult(
      await this.model.listar(
        {
          fecha: filtro.fecha,
          tipoLote: filtro.tipo_lote,
          limite: filtro.limite ?? 10,
          offset: filtro.offset,
        },
        idEmpresa,
      ),
      filtro,
    );
  }

  async archivo(
    id: number,
    tipo: 'xml' | 'cdr',
    idEmpresa: number | null,
  ): Promise<ArchivoSunat> {
    const lote = await this.model.obtener(id, idEmpresa);
    if (!lote) throw new NotFoundException('El lote no existe');
    return tipo === 'xml'
      ? this.archivos.leer(
          lote.rutaXml,
          `${lote.identificador}.xml`,
          TIPO_ARCHIVO.xml,
        )
      : this.archivos.leer(
          lote.rutaCdr,
          `R-${lote.identificador}.zip`,
          TIPO_ARCHIVO.zip,
        );
  }

  private async enviarLote(
    tipoLote: TipoLote,
    dia: string,
    items: {
      idComprobante: number;
      estadoItem: EstadoItem;
      motivo?: string | null;
    }[],
    usuario: number | null,
    idEmpresa: number | null,
  ) {
    const { emisor, token } = await this.configuracion.contexto(idEmpresa);
    const lote = await this.model.crear(
      tipoLote,
      dia,
      items,
      usuario,
      idEmpresa,
    );
    if (!lote)
      throw new BadRequestException(
        'Ningún comprobante se puede incluir: ya fueron enviados, están en proceso o tienen otra baja en curso',
      );
    try {
      const datos = await this.itemsLote(lote);
      const cuerpo =
        tipoLote === TipoLote.BAJA
          ? construirBaja(
              datos,
              emisor,
              lote.fechaDocumentos,
              lote.fechaEnvio,
              lote.correlativo,
            )
          : construirResumen(
              datos,
              emisor,
              lote.fechaDocumentos,
              lote.fechaEnvio,
              lote.correlativo,
            );
      const respuesta =
        tipoLote === TipoLote.BAJA
          ? await this.apisPeru.enviarBaja(token, cuerpo)
          : await this.apisPeru.enviarResumen(token, cuerpo);
      const ticket = respuesta.sunatResponse?.ticket;
      if (!respuesta.sunatResponse?.success || !ticket) {
        const e = respuesta.sunatResponse?.error;
        const mensaje = e
          ? `${e.code ?? ''} ${e.message ?? ''}`.trim()
          : 'SUNAT no devolvió ticket';
        await this.model.resolver(lote.id, false, { codigo: e?.code, mensaje });
        await this.comprobantes.bitacora({
          idLote: lote.id,
          operacion: tipoLote === TipoLote.BAJA ? 'BAJA' : 'RESUMEN',
          exito: false,
          codigo: e?.code,
          mensaje,
          respuesta: respuesta.sunatResponse,
          usuario,
        });
        throw new BadRequestException(
          `${lote.identificador} no aceptado: ${mensaje}`,
        );
      }
      const rutaXml = respuesta.xml
        ? await this.archivos.guardar(
            `sunat/${emisor.ruc}/lotes/${emisor.ruc}-${lote.identificador}.xml`,
            respuesta.xml,
            TIPO_ARCHIVO.xml,
          )
        : null;
      await this.model.registrarTicket(lote.id, ticket, rutaXml);
      await this.comprobantes.bitacora({
        idLote: lote.id,
        operacion: tipoLote === TipoLote.BAJA ? 'BAJA' : 'RESUMEN',
        exito: true,
        codigo: ticket,
        mensaje: `Ticket ${ticket} (${lote.items.length} comprobantes)`,
        usuario,
      });
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      const mensaje = (error as Error).message;
      await this.model.resolver(lote.id, false, { mensaje });
      await this.comprobantes.bitacora({
        idLote: lote.id,
        operacion: tipoLote === TipoLote.BAJA ? 'BAJA' : 'RESUMEN',
        exito: false,
        codigo:
          error instanceof ApisPeruFallo && error.status
            ? `HTTP ${error.status}`
            : 'RED',
        mensaje,
        respuesta: error instanceof ApisPeruFallo ? error.detalle : undefined,
        usuario,
      });
      throw new BadRequestException(
        `${lote.identificador} no se envió: ${mensaje}`,
      );
    }
    // SUNAT suele responder en segundos: se intenta una primera consulta del ticket.
    await this.consultarPendientes(lote.id).catch(() => undefined);
    return this.obtener(lote.id);
  }

  private async consultarLote(lote: LoteEnProceso) {
    const { emisor, token } = await this.configuracion.contexto(
      lote.idEmpresa,
    );
    await this.model.marcarConsulta(lote.id);
    const estado =
      lote.tipoLote === TipoLote.BAJA
        ? await this.apisPeru.estadoBaja(token, lote.ticket)
        : await this.apisPeru.estadoResumen(token, lote.ticket);
    const r = interpretarTicket(estado);
    if (r.estado === EstadoSunat.EN_PROCESO) return;
    const rutaCdr = r.cdrZip
      ? await this.archivos.guardar(
          `sunat/${emisor.ruc}/lotes/R-${emisor.ruc}-${lote.identificador}.zip`,
          Buffer.from(r.cdrZip, 'base64'),
          TIPO_ARCHIVO.zip,
        )
      : null;
    const aceptado = r.estado === EstadoSunat.ACEPTADO;
    await this.model.resolver(lote.id, aceptado, {
      codigo: r.codigo,
      mensaje: [r.mensaje, r.observaciones].filter(Boolean).join('\n') || null,
      rutaCdr,
    });
    await this.comprobantes.bitacora({
      idLote: lote.id,
      operacion: 'CONSULTA_TICKET',
      exito: aceptado,
      codigo: r.codigo,
      mensaje: r.mensaje,
      respuesta: {
        code: estado.code,
        error: estado.error,
        cdrResponse: estado.cdrResponse,
      },
    });
    if (!aceptado)
      await this.emision.avisar(
        null,
        `${lote.tipoLote === TipoLote.BAJA ? 'Baja' : 'Resumen diario'} no aceptado por SUNAT`,
        `${lote.identificador}: ${r.mensaje ?? 'sin detalle'}.${
          lote.tipoLote === TipoLote.RESUMEN
            ? ' Las boletas quedaron pendientes para reenviarlas.'
            : ''
        }`,
        'error',
      );
  }

  private async itemsLote(lote: LoteCreado): Promise<ItemLote[]> {
    const lista = await this.comprobantes.comprobantes(
      lote.items.map((i) => i.idComprobante),
      lote.idEmpresa,
    );
    const porId = new Map(lista.map((c) => [c.id, c]));
    return lote.items.map((i) => ({
      comprobante: porId.get(i.idComprobante)!,
      estadoItem: i.estadoItem,
      motivo: i.motivo,
    }));
  }
}
