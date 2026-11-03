/** Ruta de cada operación de APIsPERU, relativa a APISPERU_URL (.env). */
export const RUTAS_APISPERU = {
  facturaEnvio: 'invoice/send',
  facturaXml: 'invoice/xml',
  facturaPdf: 'invoice/pdf',
  facturaEstado: 'invoice/status',
  resumenEnvio: 'summary/send',
  resumenEstado: 'summary/status',
  bajaEnvio: 'voided/send',
  bajaEstado: 'voided/status',
} as const;
export type OperacionApisPeru = keyof typeof RUTAS_APISPERU;

/** Rutas de la API de consultas DNI/RUC, relativas a APISPERU_CONSULTAS_URL (.env). */
export const RUTAS_CONSULTAS_APISPERU = {
  dni: 'dni',
  ruc: 'ruc',
} as const;
