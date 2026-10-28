/** Respuestas de APIsPERU (swagger «API DE FACTURACIÓN» v1.3). */

export interface ApisPeruError {
  code?: string;
  message?: string;
}

export interface CdrResponse {
  accepted?: boolean;
  id?: string;
  code?: string;
  description?: string;
  notes?: string[];
}

/** sunatResponse del envío de boleta/factura. */
export interface BillResult {
  success: boolean;
  error?: ApisPeruError | null;
  cdrZip?: string | null;
  cdrResponse?: CdrResponse | null;
}

/** Envío de boleta/factura. */
export interface DocumentResponse {
  xml?: string;
  hash?: string;
  sunatResponse?: BillResult;
}

/** sunatResponse del resumen diario y de la baja: SUNAT devuelve un ticket. */
export interface SummaryResult {
  success: boolean;
  error?: ApisPeruError | null;
  ticket?: string | null;
}

export interface SummaryResponse {
  xml?: string;
  hash?: string;
  sunatResponse?: SummaryResult;
}

/** Consulta de CDR o de ticket. code «98» = en proceso. */
export interface StatusResult {
  success?: boolean;
  error?: ApisPeruError | null;
  cdrZip?: string | null;
  cdrResponse?: CdrResponse | null;
  code?: string | null;
}

/** 400 de validación: [{ message, field }]. */
export interface ValidacionApisPeru {
  message?: string;
  field?: string;
}
