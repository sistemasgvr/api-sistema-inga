/**
 * Topes generales para montos y cantidades.
 *
 * Las columnas NUMERIC más chicas son (10,2); sin este tope un valor de 12
 * cifras llegaba a la BD y salía como "Error interno del servidor".
 * El front usa el mismo valor (`src/shared/constants/limites.ts`).
 */
export const MONTO_MAXIMO = 9_999_999;
export const CANTIDAD_MAXIMA = 9_999_999;
/** Cantidad de billetes o monedas de una denominación en el arqueo. */
export const CANTIDAD_BILLETES_MAXIMA = 99_999;
