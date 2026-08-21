import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';

@Injectable()
export class LoginModel {
  constructor(private readonly db: DatabaseService) {}

  obtenerUsuarioPorLogin(email: string) {
    return this.db.callFunctionJson<AuthSingleResult<{
      id: number;
      username: string;
      email: string;
      password_hash: string;
      pin_hash: string | null;
      nombres: string;
      apellidos: string;
      telefono: string | null;
      id_sucursal_default: number | null;
      es_super_admin: boolean;
      estado: number;
      roles: { id: number; codigo: string; nombre: string }[];
    }>>('auth_obtener_usuario_por_login', [email]);
  }

  crearSesion(
    idUsuario: number,
    tokenHash: string,
    ip: string | null,
    userAgent: string | null,
  ) {
    return this.db.callFunctionJson<{ id_sesion: number }>('auth_crear_sesion', [
      idUsuario,
      tokenHash,
      ip,
      userAgent,
    ]);
  }

  cerrarSesion(idSesion: number, idUsuario: number) {
    return this.db.callFunctionJson<{ cerrada: boolean; id: number }>(
      'auth_cerrar_sesion',
      [idSesion, idUsuario],
    );
  }

  obtenerPermisosUsuario(idUsuario: number) {
    return this.db.callFunctionJson<{ permisos: string[] }>(
      'auth_obtener_permisos_usuario',
      [idUsuario],
    );
  }
}