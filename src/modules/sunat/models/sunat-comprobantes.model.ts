import { Injectable } from '@nestjs/common';
import type {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import type { ComprobanteSunat, EmisorSunat } from '../helpers/documentos';

export interface EmisorRegistro extends EmisorSunat {
  tokenCifrado: string | null;
  idAmbiente: number;
}

/** Comprobante con su estado SUNAT y las rutas de sus archivos en Storage. */
export interface ComprobanteEstado extends ComprobanteSunat {
  idEmpresa: number;
  idPedido: number;
  estado: number;
  estadoSunat: number;
  formaEnvio: number | null;
  montoIgv: number;
  montoTotal: number;
  hash: string | null;
  rutaXml: string | null;
  rutaCdr: string | null;
  rutaPdfA4: string | null;
  fechaLimiteEnvio: string | null;
  codigoRespuesta: string | null;
  mensaje: string | null;
  observaciones: string | null;
  intentos: number;
  fechaEnvio: string | null;
}

export interface ResultadoEnvio {
  estadoSunat: number;
  codigo?: string | null;
  mensaje?: string | null;
  observaciones?: string | null;
  hash?: string | null;
  rutaXml?: string | null;
  rutaCdr?: string | null;
}

export interface BitacoraSunat {
  idComprobante?: number | null;
  idLote?: number | null;
  operacion: string;
  exito: boolean;
  codigo?: string | null;
  mensaje?: string | null;
  respuesta?: unknown;
  usuario?: number | null;
}

export interface ComprobanteDia {
  id: number;
  idPedido: number;
  tipoComprobante: number;
  numero: string;
  receptorNumDoc: string | null;
  receptorRazonSocial: string | null;
  montoTotal: number;
  estado: number;
  estadoSunat: number;
  formaEnvio: number | null;
  sunatMensaje: string | null;
  fechaLimiteEnvio: string | null;
  fechaEmision: string;
}

interface FilaEmisor {
  ruc: string;
  razon_social: string;
  nombre_comercial: string | null;
  direccion: string | null;
  ubigeo: string | null;
  distrito: string | null;
  provincia: string | null;
  departamento: string | null;
  token_emision_cifrado: string | null;
  id_ambiente: number;
}

interface FilaComprobante {
  id: number;
  id_empresa: number;
  id_pedido: number;
  tipo_comprobante: number;
  serie: string;
  correlativo: string;
  fecha_emision: string;
  receptor_tipo_doc: number | null;
  receptor_num_doc: string | null;
  receptor_razon_social: string | null;
  receptor_direccion: string | null;
  estado: number;
  estado_sunat: number;
  forma_envio: number | null;
  monto_igv: number;
  monto_total: number;
  hash_qr: string | null;
  ruta_xml: string | null;
  ruta_cdr: string | null;
  ruta_pdf_a4: string | null;
  fecha_limite_envio: string | null;
  codigo_respuesta_sunat: string | null;
  sunat_mensaje: string | null;
  observaciones_sunat: string | null;
  intentos_envio: number;
  fecha_envio_sunat: string | null;
  lineas: {
    id_producto: number | null;
    descripcion: string;
    cantidad: number;
    unidad_sunat: string;
    tipo_afectacion_igv: string;
    tasa_igv: number;
    valor_unitario: number;
    precio_unitario_igv: number;
    monto_base_igv: number;
    monto_igv: number;
  }[];
}

interface FilaDia {
  id: number;
  id_pedido: number;
  tipo_comprobante: number;
  numero: string;
  receptor_num_doc: string | null;
  receptor_razon_social: string | null;
  monto_total: number;
  estado: number;
  estado_sunat: number;
  forma_envio: number | null;
  sunat_mensaje: string | null;
  fecha_limite_envio: string | null;
  fecha_emision: string;
}

/** Acceso a datos de comprobantes electrónicos: todo pasa por funciones ven_sunat_*. */
@Injectable()
export class SunatComprobantesModel {
  constructor(private readonly db: DatabaseService) {}

  /** Datos del emisor (empresa de la sesión) con el ubigeo de su distrito y el token cifrado. */
  async emisor(idEmpresa: number | null): Promise<EmisorRegistro | null> {
    const { registro: r } = await this.db.callFunctionJson<
      AuthSingleResult<FilaEmisor>
    >('gen_obtener_emisor_sunat', [idEmpresa]);
    if (!r) return null;
    return {
      ruc: r.ruc,
      razonSocial: r.razon_social,
      nombreComercial: r.nombre_comercial,
      direccion: r.direccion,
      ubigeo: r.ubigeo,
      distrito: r.distrito,
      provincia: r.provincia,
      departamento: r.departamento,
      tokenCifrado: r.token_emision_cifrado,
      idAmbiente: r.id_ambiente,
    };
  }

  async comprobantes(
    ids: number[],
    idEmpresa?: number | null,
  ): Promise<ComprobanteEstado[]> {
    if (!ids.length) return [];
    const { registros } = await this.db.callFunctionJson<
      AuthListResult<FilaComprobante>
    >('ven_sunat_obtener_comprobantes', [ids, idEmpresa ?? null]);
    return registros.map((r) => ({
      id: r.id,
      idEmpresa: Number(r.id_empresa),
      idPedido: r.id_pedido,
      tipoComprobante: r.tipo_comprobante,
      serie: r.serie,
      correlativo: r.correlativo,
      fechaEmision: new Date(r.fecha_emision).toISOString(),
      receptorTipoDoc: r.receptor_tipo_doc,
      receptorNumDoc: r.receptor_num_doc,
      receptorRazonSocial: r.receptor_razon_social,
      receptorDireccion: r.receptor_direccion,
      estado: r.estado,
      estadoSunat: r.estado_sunat,
      formaEnvio: r.forma_envio,
      montoIgv: Number(r.monto_igv),
      montoTotal: Number(r.monto_total),
      hash: r.hash_qr,
      rutaXml: r.ruta_xml,
      rutaCdr: r.ruta_cdr,
      rutaPdfA4: r.ruta_pdf_a4,
      fechaLimiteEnvio: r.fecha_limite_envio,
      codigoRespuesta: r.codigo_respuesta_sunat,
      mensaje: r.sunat_mensaje,
      observaciones: r.observaciones_sunat,
      intentos: r.intentos_envio,
      fechaEnvio: r.fecha_envio_sunat,
      lineas: r.lineas.map((l) => ({
        idProducto: l.id_producto,
        descripcion: l.descripcion,
        cantidad: Number(l.cantidad),
        unidadSunat: l.unidad_sunat,
        tipoAfectacionIgv: l.tipo_afectacion_igv,
        tasaIgv: Number(l.tasa_igv),
        valorUnitario: Number(l.valor_unitario),
        precioUnitarioIgv: Number(l.precio_unitario_igv),
        montoBaseIgv: Number(l.monto_base_igv),
        montoIgv: Number(l.monto_igv),
      })),
    }));
  }

  async comprobante(id: number, idEmpresa?: number | null) {
    return (await this.comprobantes([id], idEmpresa))[0] ?? null;
  }

  /** Reserva el comprobante para un envío individual (solo uno a la vez). */
  async reservarEnvio(id: number) {
    const { reservado } = await this.db.callFunctionJson<{
      reservado: boolean;
    }>('ven_sunat_reservar_envio', [id]);
    return reservado;
  }

  async guardarResultado(id: number, r: ResultadoEnvio) {
    await this.db.callFunctionJson('ven_sunat_guardar_resultado', [
      id,
      JSON.stringify({
        estado_sunat: r.estadoSunat,
        codigo: r.codigo ?? null,
        mensaje: r.mensaje ?? null,
        observaciones: r.observaciones ?? null,
        hash: r.hash ?? null,
        ruta_xml: r.rutaXml ?? null,
        ruta_cdr: r.rutaCdr ?? null,
      }),
    ]);
  }

  async guardarRuta(id: number, tipo: 'XML' | 'PDF_A4', ruta: string) {
    await this.db.callFunctionJson('ven_sunat_guardar_archivo', [
      id,
      tipo,
      ruta,
    ]);
  }

  async bitacora(b: BitacoraSunat) {
    await this.db.callFunctionJson('ven_sunat_registrar_bitacora', [
      JSON.stringify({
        id_comprobante: b.idComprobante ?? null,
        id_lote: b.idLote ?? null,
        operacion: b.operacion,
        exito: b.exito,
        codigo: b.codigo ?? null,
        mensaje: b.mensaje ?? null,
        respuesta: b.respuesta ?? null,
        id_usuario: b.usuario ?? null,
      }),
    ]);
  }

  async historial(id: number) {
    const { registros } = await this.db.callFunctionJson<AuthListResult>(
      'ven_sunat_historial_comprobante',
      [id],
    );
    return registros;
  }

  /** Pendientes cuya fecha límite ya llegó (programador). */
  async vencidos(limite = 200, idEmpresa?: number | null) {
    const { registros } = await this.db.callFunctionJson<
      AuthListResult<{ id: number; tipo_comprobante: number; dia: string }>
    >('ven_sunat_listar_vencidos', [limite, idEmpresa ?? null]);
    return registros.map((r) => ({
      id: r.id,
      tipoComprobante: r.tipo_comprobante,
      dia: r.dia,
    }));
  }

  /** Envíos individuales que quedaron «en proceso» sin respuesta vuelven a pendientes. */
  async liberarColgados() {
    const { liberados } = await this.db.callFunctionJson<{
      liberados: number;
    }>('ven_sunat_liberar_envios_colgados');
    return liberados;
  }

  /** Pendientes que vencen hoy o mañana: para el aviso diario. */
  async porVencer(idEmpresa?: number | null) {
    const { registros } = await this.db.callFunctionJson<
      AuthListResult<{
        tipo_comprobante: number;
        cantidad: number;
        vence: string;
      }>
    >('ven_sunat_resumen_por_vencer', [idEmpresa ?? null]);
    return registros.map((r) => ({
      tipoComprobante: r.tipo_comprobante,
      cantidad: Number(r.cantidad),
      vence: r.vence,
    }));
  }

  /** Boletas y facturas emitidas en un día de Lima. */
  async delDia(
    dia: string,
    idEmpresa?: number | null,
  ): Promise<ComprobanteDia[]> {
    const { registros } = await this.db.callFunctionJson<
      AuthListResult<FilaDia>
    >('ven_sunat_listar_comprobantes_dia', [dia, idEmpresa ?? null]);
    return registros.map((r) => ({
      id: r.id,
      idPedido: r.id_pedido,
      tipoComprobante: r.tipo_comprobante,
      numero: r.numero,
      receptorNumDoc: r.receptor_num_doc,
      receptorRazonSocial: r.receptor_razon_social,
      montoTotal: Number(r.monto_total),
      estado: r.estado,
      estadoSunat: r.estado_sunat,
      formaEnvio: r.forma_envio,
      sunatMensaje: r.sunat_mensaje,
      fechaLimiteEnvio: r.fecha_limite_envio,
      fechaEmision: r.fecha_emision,
    }));
  }

  /** Pendientes, en proceso y rechazados (o el estado indicado). */
  bandeja(
    filtro: {
      estadoSunat?: number;
      tipoComprobante?: number;
      limite: number;
      offset: number;
    },
    idEmpresa?: number | null,
  ) {
    return this.db.callFunctionJson<AuthListResult>(
      'ven_sunat_listar_bandeja',
      [
        filtro.estadoSunat ?? null,
        filtro.tipoComprobante ?? null,
        filtro.limite,
        filtro.offset,
        idEmpresa ?? null,
      ],
    );
  }

  /** Comprobante vigente de un pedido, para decidir la baja al reemitir. */
  async vigenteDelPedido(idPedido: number) {
    const { registro } = await this.db.callFunctionJson<
      AuthSingleResult<{
        id: number;
        id_empresa: number;
        estado_sunat: number;
        tipo_comprobante: number;
      }>
    >('ven_sunat_comprobante_vigente', [idPedido]);
    return registro
      ? {
          id: registro.id,
          idEmpresa: Number(registro.id_empresa),
          estadoSunat: registro.estado_sunat,
          tipoComprobante: registro.tipo_comprobante,
        }
      : null;
  }
}
