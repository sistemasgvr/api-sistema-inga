/** ven_comprobante.estado_sunat (lista SUNAT_ESTADO). */
export const EstadoSunat = {
  NO_APLICA: 0,
  PENDIENTE: 1,
  ACEPTADO: 2,
  RECHAZADO: 3,
  ANULADO: 4,
  EN_PROCESO: 5,
} as const;
export type EstadoSunat = (typeof EstadoSunat)[keyof typeof EstadoSunat];

/** ven_comprobante.tipo_comprobante que se envían a SUNAT. */
export const TipoComprobante = { BOLETA: 1, FACTURA: 2 } as const;

/** Catálogo SUNAT 01. */
export const CODIGO_TIPO_DOC: Record<number, '01' | '03'> = {
  1: '03',
  2: '01',
};

/** ven_comprobante.forma_envio. */
export const FormaEnvio = { INDIVIDUAL: 1, RESUMEN: 2 } as const;

/** ven_sunat_lote.tipo_lote. */
export const TipoLote = { RESUMEN: 1, BAJA: 2 } as const;
export type TipoLote = (typeof TipoLote)[keyof typeof TipoLote];

/** ven_sunat_lote_detalle.estado_item (catálogo SUNAT 19). */
export const EstadoItem = { ADICIONAR: 1, ANULAR: 3 } as const;
export type EstadoItem = (typeof EstadoItem)[keyof typeof EstadoItem];

/** SUNAT admite hasta 500 comprobantes por resumen diario. */
export const MAX_ITEMS_RESUMEN = 500;

/** La baja de un comprobante aceptado solo se admite hasta 7 días después de emitido. */
export const DIAS_MAXIMOS_BAJA = 7;

export const ZONA_LIMA = 'America/Lima';
