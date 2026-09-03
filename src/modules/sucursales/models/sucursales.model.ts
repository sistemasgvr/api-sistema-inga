import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { FiltroSucursalDto, SucursalEstadoFiltro } from '../dto/filtros-sucursal.dto';

export interface SucursalListResult {
  registros: any[];
  total: number;
  resumen?: {
    total: number;
    activos: number;
    inactivos: number;
  };
}

@Injectable()
export class SucursalesModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: SucursalEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroSucursalDto) {
    return this.db.callFunctionJson<SucursalListResult>('gen_listar_sucursales', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_sucursal', [id]);
  }

  crear(
    idEmpresa: number,
    codigo: string,
    nombre: string,
    direccion?: string,
    telefono?: string,
    idDistrito?: number,
    esPrincipal?: boolean,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_sucursal', [
      idEmpresa,
      codigo,
      nombre,
      direccion ?? null,
      telefono ?? null,
      idDistrito ?? null,
      esPrincipal ?? false,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    idEmpresa?: number,
    codigo?: string,
    nombre?: string,
    direccion?: string,
    telefono?: string,
    idDistrito?: number,
    esPrincipal?: boolean,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_actualizar_sucursal', [
      id,
      idEmpresa ?? null,
      codigo ?? null,
      nombre ?? null,
      direccion ?? null,
      telefono ?? null,
      idDistrito ?? null,
      esPrincipal ?? null,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_sucursal', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('gen_activar_sucursal', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}