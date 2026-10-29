import { Injectable } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateCategoriaProductoDto,
  FiltroCategoriasProductoDto,
  UpdateCategoriaProductoDto,
} from '../dto/categorias-producto.dto';
import { CategoriasProductoModel } from '../models/categorias-producto.model';

@Injectable()
export class CategoriasProductoLogic {
  constructor(private readonly categoriasProductoModel: CategoriasProductoModel) {}

  async listar(filtros: FiltroCategoriasProductoDto, idEmpresa?: number | null) {
    const result = await this.categoriasProductoModel.listar(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number, idEmpresa?: number | null) {
    const result = await this.categoriasProductoModel.obtenerPorId(id, idEmpresa);
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async crear(dto: CreateCategoriaProductoDto, idEmpresa?: number | null) {
    const result = await this.categoriasProductoModel.crear(
      dto.nombre,
      dto.descripcion ?? null,
      dto.es_carta ?? false,
      dto.orden ?? 0,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(result, 'No se pudo crear la categoría');
  }

  async actualizar(id: number, dto: UpdateCategoriaProductoDto, idEmpresa?: number | null) {
    const result = await this.categoriasProductoModel.actualizar(
      id,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.es_carta ?? null,
      dto.orden ?? null,
      dto.idUsuarioAuditoria,
      idEmpresa,
    );
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number, idEmpresa?: number | null) {
    const result = await this.categoriasProductoModel.eliminar(id, idUsuarioAuditoria, idEmpresa);
    return mapDeleteResult(result, `Categoría con ID ${id} no encontrada o ya inactiva`);
  }

  async activar(id: number, idUsuarioAuditoria?: number, idEmpresa?: number | null) {
    const result = await this.categoriasProductoModel.activar(id, idUsuarioAuditoria, idEmpresa);
    
    if (!result || (result as any).eliminado === false) {
      return { message: "La categoría ya se encontraba activa o fue actualizada", data: { id } };
    }

    return result;
  }
}

