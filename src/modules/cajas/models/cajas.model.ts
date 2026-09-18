import { Injectable } from '@nestjs/common';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CajaEstadoFiltro, FiltroCajasDto } from '../dto/cajas.dto';

@Injectable()
export class CajasModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: CajaEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroCajasDto) {
    return this.db.callFunctionJson<AuthListResult>('caj_listar_cajas', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_sucursal ?? null,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_obtener_caja', [id]);
  }

  crear(
    idSucursal: number,
    codigo: string,
    nombre: string,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_crear_caja', [
      idSucursal,
      codigo,
      nombre,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    idSucursal: number | null,
    codigo: string | null,
    nombre: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('caj_actualizar_caja', [
      id,
      idSucursal,
      codigo,
      nombre,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('caj_eliminar_caja', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('caj_activar_caja', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
