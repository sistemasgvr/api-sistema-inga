import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
  AuthActivateResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { AlmacenEstadoFiltro, FiltroAlmacenesDto } from '../dto/almacenes.dto';

@Injectable()
export class AlmacenesModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: AlmacenEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroAlmacenesDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_almacenes', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_sucursal ?? null,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_almacen', [id]);
  }

  crear(
    idSucursal: number,
    nombre: string,
    descripcion: string | null,
    tipoAlmacen: number,
    esPrincipal: boolean,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_almacen', [
      idSucursal,
      nombre,
      descripcion,
      tipoAlmacen,
      esPrincipal,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    idSucursal: number | null,
    nombre: string | null,
    descripcion: string | null,
    tipoAlmacen: number | null,
    esPrincipal: boolean | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_actualizar_almacen', [
      id,
      idSucursal,
      nombre,
      descripcion,
      tipoAlmacen,
      esPrincipal,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_almacen', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('gen_activar_almacen', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
