import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroRolDto, RolEstadoFiltro } from '../dto/filtros-rol.dto';

export interface AuthAsignarRolesUsuarioResult {
  actualizado: boolean;
  id_usuario: number;
  error?: string;
}

@Injectable()
export class RolesModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: RolEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroRolDto) {
    return this.db.callFunctionJson<AuthListResult>('auth_listar_roles', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_obtener_rol', [id]);
  }

  crear(
    codigo: string,
    nombre: string,
    descripcion?: string,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_crear_rol', [
      codigo,
      nombre,
      descripcion ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    codigo: string | null,
    nombre: string | null,
    descripcion: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_actualizar_rol', [
      id,
      codigo,
      nombre,
      descripcion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('auth_eliminar_rol', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('auth_activar_rol', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  asignarPermisos(idRol: number, idsPermisos: number[], idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_asignar_permisos_rol', [
      idRol,
      idsPermisos,
      idUsuarioAuditoria ?? null,
    ]);
  }

  asignarRolesAUsuario(idUsuario: number, idsRoles: number[], idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthAsignarRolesUsuarioResult>('auth_asignar_roles_usuario', [
      idUsuario,
      idsRoles,
      idUsuarioAuditoria ?? null,
    ]);
  }
}