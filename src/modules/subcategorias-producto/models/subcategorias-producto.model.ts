import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
  AuthActivateResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { SubCategoriaEstadoFiltro, FiltroSubCategoriasProductoDto } from '../dto/subcategorias-producto.dto';

@Injectable()
export class SubCategoriasProductoModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: SubCategoriaEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroSubCategoriasProductoDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_sub_categorias', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.id_categoria ?? null,
      this.resolveEstadoFiltro(filtros.estado),
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_sub_categoria', [id]);
  }

  crear(
    id_categoria: number,
    codigo: string,
    nombre: string,
    orden: number,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_sub_categoria', [
      id_categoria,
      codigo,
      nombre,
      orden,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    id_categoria: number | null,
    codigo: string | null,
    nombre: string | null,
    orden: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_sub_categoria', [
      id,
      id_categoria,
      codigo,
      nombre,
      orden,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_sub_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('pro_activar_sub_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}