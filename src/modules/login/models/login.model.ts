import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';

/** Sucursal en la que puede trabajar el usuario (auth_sucursales_usuario). */
export interface SucursalUsuario {
  id: number;
  codigo: string;
  nombre: string;
  es_predeterminada: boolean;
}

@Injectable()
export class LoginModel {
  constructor(private readonly db: DatabaseService) {}

  obtenerUsuarioPorLogin(email: string) {
    return this.db.callFunctionJson<
      AuthSingleResult<{
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
        id_empresa: number | null;
        empresa: { id: number; ruc: string; razon_social: string } | null;
        sucursales: SucursalUsuario[];
      }>
    >('auth_obtener_usuario_por_login', [email]);
  }

  crearSesion(
    idUsuario: number,
    tokenHash: string,
    ip: string | null,
    userAgent: string | null,
  ) {
    return this.db.callFunctionJson<{
      id_sesion: number;
      id_sucursal_activa: number | null;
    }>('auth_crear_sesion', [idUsuario, tokenHash, ip, userAgent]);
  }

  cerrarSesion(idSesion: number, idUsuario: number) {
    return this.db.callFunctionJson<{ cerrada: boolean; id: number }>(
      'auth_cerrar_sesion',
      [idSesion, idUsuario],
    );
  }
  cambiarSucursal(idSesion: number, idUsuario: number, idSucursal: number) {
    return this.db.callFunctionJson<
      AuthSingleResult<{ id: number; codigo: string; nombre: string }>
    >('auth_cambiar_sucursal_sesion', [idSesion, idUsuario, idSucursal]);
  }

  sucursalesUsuario(idUsuario: number) {
    return this.db.callFunctionJson<SucursalUsuario[]>(
      'auth_sucursales_usuario',
      [idUsuario],
    );
  }

  obtenerPermisosUsuario(idUsuario: number) {
    return this.db.callFunctionJson<{ permisos: string[] }>(
      'auth_obtener_permisos_usuario',
      [idUsuario],
    );
  }
}
