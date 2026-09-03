export interface AuthenticatedUser {
  id: number;
  email: string;
  username: string;
  nombres: string;
  apellidos: string;
  es_super_admin: boolean; 
  permisos: string[];
  sesion: {
    id: number;
    id_usuario: number;
    username: string;
    email: string;
    fecha_inicio: string;
  };
}