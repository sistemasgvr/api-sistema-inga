export interface AuthenticatedUser {
  id: number;
  email: string;
  username: string;
  nombres: string;
  apellidos: string;
  es_super_admin: boolean;
  permisos: string[];
  id_empresa: number | null;
  id_sucursal: number | null;
  sesion: {
    id: number;
    id_usuario: number;
    username: string;
    email: string;
    fecha_inicio: string;
  };
}
