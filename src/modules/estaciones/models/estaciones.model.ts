import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
  AuthActivateResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { EstacionEstadoFiltro, FiltroEstacionesDto } from '../dto/estaciones.dto';

@Injectable()
export class EstacionesModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: EstacionEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroEstacionesDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_estaciones', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_sucursal ?? null,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_estacion', [id]);
  }

  crear(
    idSucursal: number,
    codigo: string,
    nombre: string,
    tipoEstacion: number,
    impresoraNombre: string | null,
    impresoraIp: string | null,
    usaKds: boolean,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_estacion', [
      idSucursal,
      codigo,
      nombre,
      tipoEstacion,
      impresoraNombre,
      impresoraIp,
      usaKds,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    idSucursal: number | null,
    codigo: string | null,
    nombre: string | null,
    tipoEstacion: number | null,
    impresoraNombre: string | null,
    impresoraIp: string | null,
    usaKds: boolean | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_actualizar_estacion', [
      id,
      idSucursal,
      codigo,
      nombre,
      tipoEstacion,
      impresoraNombre,
      impresoraIp,
      usaKds,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_estacion', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('gen_activar_estacion', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}