export interface AuthListResult<T = unknown> {
  registros: T[];
  total: number;
  resumen?: {
    total: number;
    activos: number;
    inactivos: number;
  };
}

export interface AuthSingleResult<T = unknown> {
  registro: T | null;
  error?: string;
}

export interface AuthDeleteResult {
  eliminado: boolean;
  id: number;
  error?: string;
}

export interface AuthActivateResult {
  activado: boolean;
  id: number;
  error?: string;
}

export interface AuthCloseResult {
  cerrada: boolean;
  id: number;
}

export interface AuthSessionValidateResult<T = unknown> {
  valida: boolean;
  registro: T | null;
}

export interface AuthExisteResult {
  existe: boolean;
}
