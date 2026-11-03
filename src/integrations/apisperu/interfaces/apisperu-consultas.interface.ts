export interface ConsultaDni {
  dni: string;
  nombres: string;
  apellidoPaterno: string;
  apellidoMaterno: string;
  codVerifica?: string;
}

export interface ConsultaRuc {
  ruc: string;
  razonSocial: string;
  nombreComercial?: string | null;
  telefonos?: string[];
  estado?: string | null;
  condicion?: string | null;
  direccion?: string | null;
  departamento?: string | null;
  provincia?: string | null;
  distrito?: string | null;
  ubigeo?: string | null;
  capital?: string | null;
}
