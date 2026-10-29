import { BadRequestException, Injectable } from '@nestjs/common';
import type {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { EstadoItem, TipoLote } from '../constants/sunat';

export interface ItemNuevoLote {
  idComprobante: number;
  estadoItem: EstadoItem;
  motivo?: string | null;
}

export interface LoteCreado {
  id: number;
  idEmpresa: number;
  tipoLote: TipoLote;
  correlativo: number;
  fechaEnvio: string;
  fechaDocumentos: string;
  identificador: string;
  items: ItemNuevoLote[];
}

export interface LoteEnProceso {
  id: number;
  idEmpresa: number;
  tipoLote: TipoLote;
  ticket: string;
  identificador: string;
  intentos: number;
}

interface FilaLote {
  id: number;
  tipo_lote: TipoLote;
  identificador: string;
  estado_sunat: number;
  ticket: string | null;
  ruta_xml: string | null;
  ruta_cdr: string | null;
  [campo: string]: unknown;
}

/** Resúmenes diarios (RC) y comunicaciones de baja (RA): funciones ven_sunat_*_lote. */
@Injectable()
export class SunatLotesModel {
  constructor(private readonly db: DatabaseService) {}

  /**
   * Crea el lote con los comprobantes que aún califican (las boletas a adicionar
   * quedan «en proceso» en la misma operación). Devuelve null si ninguno calificó.
   */
  async crear(
    tipoLote: TipoLote,
    fechaDocumentos: string,
    items: ItemNuevoLote[],
    usuario: number | null,
    idEmpresa: number | null,
  ): Promise<LoteCreado | null> {
    const result = await this.db.callFunctionJson<
      AuthSingleResult<{
        id: number;
        id_empresa: number;
        tipo_lote: TipoLote;
        correlativo: number;
        fecha_envio: string;
        fecha_documentos: string;
        identificador: string;
        items: {
          id_comprobante: number;
          estado_item: EstadoItem;
          motivo: string | null;
        }[];
      }>
    >('ven_sunat_crear_lote', [
      tipoLote,
      fechaDocumentos,
      JSON.stringify(
        items.map((i) => ({
          id_comprobante: i.idComprobante,
          estado_item: i.estadoItem,
          motivo: i.motivo ?? null,
        })),
      ),
      usuario,
      idEmpresa,
    ]);
    if (result.error) throw new BadRequestException(result.error);
    const r = result.registro;
    if (!r) return null;
    return {
      id: r.id,
      idEmpresa: Number(r.id_empresa),
      tipoLote: r.tipo_lote,
      correlativo: r.correlativo,
      fechaEnvio: r.fecha_envio,
      fechaDocumentos: r.fecha_documentos,
      identificador: r.identificador,
      items: r.items.map((i) => ({
        idComprobante: i.id_comprobante,
        estadoItem: i.estado_item,
        motivo: i.motivo,
      })),
    };
  }

  /** SUNAT recibió el lote y devolvió su ticket. */
  async registrarTicket(id: number, ticket: string, rutaXml: string | null) {
    await this.db.callFunctionJson('ven_sunat_registrar_ticket_lote', [
      id,
      ticket,
      rutaXml,
    ]);
  }

  /** Cierra el lote con la respuesta de SUNAT y actualiza sus comprobantes. */
  async resolver(
    id: number,
    aceptado: boolean,
    respuesta: {
      codigo?: string | null;
      mensaje?: string | null;
      rutaCdr?: string | null;
    },
  ) {
    await this.db.callFunctionJson('ven_sunat_resolver_lote', [
      id,
      aceptado,
      JSON.stringify({
        codigo: respuesta.codigo ?? null,
        mensaje: respuesta.mensaje ?? null,
        ruta_cdr: respuesta.rutaCdr ?? null,
      }),
    ]);
  }

  async marcarConsulta(id: number) {
    await this.db.callFunctionJson('ven_sunat_marcar_consulta_lote', [id]);
  }

  /** Lotes con ticket cuya respuesta falta (o solo el indicado). */
  async enProceso(
    soloId?: number,
    idEmpresa?: number | null,
  ): Promise<LoteEnProceso[]> {
    const { registros } = await this.db.callFunctionJson<
      AuthListResult<{
        id: number;
        id_empresa: number;
        tipo_lote: TipoLote;
        ticket: string;
        identificador: string;
        intentos_consulta: number;
      }>
    >('ven_sunat_listar_lotes_en_proceso', [soloId ?? null, idEmpresa ?? null]);
    return registros.map((r) => ({
      id: r.id,
      idEmpresa: Number(r.id_empresa),
      tipoLote: r.tipo_lote,
      ticket: r.ticket,
      identificador: r.identificador,
      intentos: r.intentos_consulta,
    }));
  }

  listar(
    filtro: {
      fecha?: string;
      tipoLote?: number;
      limite: number;
      offset: number;
    },
    idEmpresa?: number | null,
  ) {
    return this.db.callFunctionJson<AuthListResult>('ven_sunat_listar_lotes', [
      filtro.fecha ?? null,
      filtro.tipoLote ?? null,
      filtro.limite,
      filtro.offset,
      idEmpresa ?? null,
    ]);
  }

  /** Lote con sus comprobantes. Las rutas de Storage van aparte: no se entregan al front. */
  async obtener(id: number, idEmpresa?: number | null) {
    const { registro: r } = await this.db.callFunctionJson<
      AuthSingleResult<FilaLote>
    >('ven_sunat_obtener_lote', [id, idEmpresa ?? null]);
    if (!r) return null;
    const { ruta_xml, ruta_cdr, ...publico } = r;
    return {
      id: r.id,
      tipoLote: r.tipo_lote,
      identificador: r.identificador,
      estadoSunat: r.estado_sunat,
      ticket: r.ticket,
      rutaXml: ruta_xml,
      rutaCdr: ruta_cdr,
      registro: {
        ...publico,
        tiene_xml: Boolean(ruta_xml),
        tiene_cdr: Boolean(ruta_cdr),
      },
    };
  }

  /** CDR del resumen aceptado que informó la boleta. */
  async cdrDeComprobante(idComprobante: number) {
    const { registro } = await this.db.callFunctionJson<
      AuthSingleResult<{ ruta_cdr: string; identificador: string }>
    >('ven_sunat_cdr_comprobante', [idComprobante]);
    return registro;
  }
}
