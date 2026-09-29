import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  FiltroUsuarioDto,
  UsuarioEstadoFiltro,
} from '../dto/filtros-usuario.dto';

export interface AuthUsuarioListResult {
  registros: any[];
  total: number;
  resumen?: {
    total: number;
    activos: number;
    inactivos: number;
  };
}

export interface TrabajadorDisponible {
  id: number;
  nombres: string;
  apellidos: string;
  email: string;
  telefono: string | null;
  nombre_sucursal: string | null;
}

@Injectable()
export class UsuariosModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: UsuarioEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroUsuarioDto) {
    return this.db.callFunctionJson<AuthUsuarioListResult>(
      'auth_listar_usuarios',
      [
        filtros.buscar ?? '',
        filtros.limite ?? 10,
        filtros.offset ?? 0,
        this.resolveEstadoFiltro(filtros.estado),
      ],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_obtener_usuario', [
      id,
    ]);
  }

  crear(
    username: string,
    idTrabajador: number,
    passwordHash: string,
    pinHash?: string | null,
    rolesIds?: number[],
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('auth_crear_usuario', [
      username,
      idTrabajador,
      passwordHash,
      pinHash ?? null,
      JSON.stringify(rolesIds ?? []),
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    username: string | null,
    passwordHash: string | null,
    pinHash: string | null,
    rolesIds: number[] | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'auth_actualizar_usuario',
      [
        id,
        username,
        passwordHash,
        pinHash,
        rolesIds ? JSON.stringify(rolesIds) : null,
        idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('auth_eliminar_usuario', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>(
      'auth_activar_usuario',
      [id, idUsuarioAuditoria ?? null],
    );
  }

  static async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }

  async trabajadoresDisponibles(id?: number) {
    const result = await this.db.callFunctionJson<{
      registros: TrabajadorDisponible[];
    }>('auth_listar_trabajadores_disponibles', [id ?? null]);
    return result.registros;
  }

  static async hashPin(pin: string): Promise<string> {
    return bcrypt.hash(pin, 10);
  }
}
