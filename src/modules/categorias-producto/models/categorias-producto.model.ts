import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
  AuthActivateResult
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CategoriaEstadoFiltro, FiltroCategoriasProductoDto } from '../dto/categorias-producto.dto';

@Injectable()
export class CategoriasProductoModel {
  constructor(private readonly db: DatabaseService) {}

  private resolveEstadoFiltro(estado?: CategoriaEstadoFiltro): number | null {
    if (estado === 'inactivos') return 0;
    if (estado === 'todos') return null;
    return 1;
  }

  listar(filtros: FiltroCategoriasProductoDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_categorias', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      this.resolveEstadoFiltro(filtros.estado),
      filtros.es_carta ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_categoria', [id]);
  }

  crear(
    codigo: string,
    nombre: string,
    descripcion: string | null,
    es_carta: boolean,
    orden: number,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_categoria', [
      codigo,
      nombre,
      descripcion,
      es_carta,
      orden,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    codigo: string | null,
    nombre: string | null,
    descripcion: string | null,
    es_carta: boolean | null,
    orden: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_categoria', [
      id,
      codigo,
      nombre,
      descripcion,
      es_carta,
      orden,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  activar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthActivateResult>('pro_activar_categoria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}