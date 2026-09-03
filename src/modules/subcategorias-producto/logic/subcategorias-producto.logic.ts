import { Injectable } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateSubCategoriaProductoDto,
  FiltroSubCategoriasProductoDto,
  UpdateSubCategoriaProductoDto,
} from '../dto/subcategorias-producto.dto';
import { SubCategoriasProductoModel } from '../models/subcategorias-producto.model';

@Injectable()
export class SubCategoriasProductoLogic {
  constructor(private readonly subCategoriasModel: SubCategoriasProductoModel) {}

  async listar(filtros: FiltroSubCategoriasProductoDto) {
    const result = await this.subCategoriasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.subCategoriasModel.obtenerPorId(id);
    return mapSingleResult(result, `Subcategoría con ID ${id} no encontrada`);
  }

  async crear(dto: CreateSubCategoriaProductoDto) {
    const result = await this.subCategoriasModel.crear(
      dto.id_categoria,
      dto.codigo,
      dto.nombre,
      dto.orden ?? 0,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la subcategoría');
  }

  async actualizar(id: number, dto: UpdateSubCategoriaProductoDto) {
    const result = await this.subCategoriasModel.actualizar(
      id,
      dto.id_categoria ?? null,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.orden ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Subcategoría con ID ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.subCategoriasModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Subcategoría con ID ${id} no encontrada o tiene productos activos`);
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.subCategoriasModel.activar(id, idUsuarioAuditoria);
    return mapActivateResult(result, `Subcategoría con ID ${id} no encontrada o ya activa`);
  }
}