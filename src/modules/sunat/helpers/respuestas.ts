/**
 * Traduce las respuestas de APIsPERU/SUNAT a estados de ven_comprobante.
 * Códigos SUNAT: 0 aceptado, 0100–1999 excepción (no se procesó: se puede reenviar),
 * 2000–3999 rechazo (el número queda usado: hay que reemitir), 4000+ aceptado con observaciones.
 */
import type {
  BillResult,
  StatusResult,
} from '../../../integrations/apisperu/interfaces/apisperu.interface';
import { EstadoSunat } from '../constants/sunat';

export interface Interpretacion {
  estado: EstadoSunat;
  codigo: string | null;
  mensaje: string | null;
  observaciones: string | null;
  cdrZip: string | null;
}

/** SUNAT ya tiene un comprobante con ese número (reenvío del mismo documento). */
export const CODIGO_YA_REGISTRADO = '1033';

const esRechazo = (codigo: string | null | undefined) => {
  const n = Number(codigo);
  return Number.isFinite(n) && n >= 2000 && n < 4000;
};

function desdeCdr(r: BillResult | StatusResult): Interpretacion | null {
  const cdr = r.cdrResponse;
  if (!cdr) return null;
  const codigo = cdr.code ?? null;
  const aceptado = cdr.accepted ?? !esRechazo(codigo);
  return {
    estado: aceptado ? EstadoSunat.ACEPTADO : EstadoSunat.RECHAZADO,
    codigo,
    mensaje: cdr.description ?? null,
    observaciones: cdr.notes?.length ? cdr.notes.join('\n') : null,
    cdrZip: r.cdrZip ?? null,
  };
}

/** Respuesta del envío o de la consulta de CDR de boleta/factura. */
export function interpretarComprobante(
  r: BillResult | StatusResult | undefined,
): Interpretacion {
  if (!r)
    return {
      estado: EstadoSunat.PENDIENTE,
      codigo: null,
      mensaje: 'APIsPERU no devolvió la respuesta de SUNAT',
      observaciones: null,
      cdrZip: null,
    };
  const cdr = desdeCdr(r);
  if (cdr) return cdr;
  const codigo = r.error?.code ?? null;
  const mensaje = r.error?.message ?? 'SUNAT no devolvió CDR';
  if (codigo === CODIGO_YA_REGISTRADO)
    return {
      estado: EstadoSunat.ACEPTADO,
      codigo,
      mensaje: 'SUNAT indica que el comprobante ya estaba registrado',
      observaciones: `${codigo}: ${mensaje}`,
      cdrZip: null,
    };
  return {
    estado: esRechazo(codigo) ? EstadoSunat.RECHAZADO : EstadoSunat.PENDIENTE,
    codigo,
    mensaje: codigo ? `${codigo}: ${mensaje}` : mensaje,
    observaciones: null,
    cdrZip: null,
  };
}

/** Respuesta de la consulta del ticket de resumen o baja (código 98: SUNAT aún lo procesa). */
export function interpretarTicket(r: StatusResult): Interpretacion {
  if (r.code === '98')
    return {
      estado: EstadoSunat.EN_PROCESO,
      codigo: '98',
      mensaje: 'SUNAT aún está procesando el ticket',
      observaciones: null,
      cdrZip: null,
    };
  const cdr = desdeCdr(r);
  if (cdr) return cdr;
  const codigo = r.error?.code ?? r.code ?? null;
  const mensaje = r.error?.message ?? 'SUNAT no devolvió CDR';
  // Sin CDR, cualquier error definitivo deja el lote sin procesar (las boletas se reenvían).
  if (r.success === false || r.error)
    return {
      estado: EstadoSunat.RECHAZADO,
      codigo,
      mensaje: codigo ? `${codigo}: ${mensaje}` : mensaje,
      observaciones: null,
      cdrZip: null,
    };
  return {
    estado: EstadoSunat.EN_PROCESO,
    codigo,
    mensaje: 'Respuesta sin CDR; se volverá a consultar',
    observaciones: null,
    cdrZip: null,
  };
}
