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

  async listar(filtros: FiltroCategoriasProductoDto) {
    const result = await this.categoriasProductoModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.categoriasProductoModel.obtenerPorId(id);
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async crear(dto: CreateCategoriaProductoDto) {
    const result = await this.categoriasProductoModel.crear(
      dto.codigo,
      dto.nombre,
      dto.descripcion ?? null,
      dto.es_carta ?? false,
      dto.orden ?? 0,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la categoría');
  }

  async actualizar(id: number, dto: UpdateCategoriaProductoDto) {
    const result = await this.categoriasProductoModel.actualizar(
      id,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.es_carta ?? null,
      dto.orden ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Categoría con ID ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.categoriasProductoModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Categoría con ID ${id} no encontrada o ya inactiva`);
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.categoriasProductoModel.activar(id, idUsuarioAuditoria);
    
    if (!result || (result as any).eliminado === false) {
      return { message: "La categoría ya se encontraba activa o fue actualizada", data: { id } };
    }

    return result;
  }
}

