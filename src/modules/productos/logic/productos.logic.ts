import { Injectable } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateProductoDto, FiltroProductosDto, UpdateProductoDto } from '../dto/productos.dto';
import { ProductosModel } from '../models/productos.model';

@Injectable()
export class ProductosLogic {
  constructor(private readonly productosModel: ProductosModel) {}

  async listar(filtros: FiltroProductosDto) {
    const result = await this.productosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.productosModel.obtenerPorId(id);
    return mapSingleResult(result, `Producto con ID ${id} no encontrado`);
  }

  async listarUnidadesMedida() {
    return await this.productosModel.listarUnidadesMedida();
  }

  async crear(dto: CreateProductoDto) {
    const result = await this.productosModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el producto');
  }

  async actualizar(id: number, dto: UpdateProductoDto) {
    const result = await this.productosModel.actualizar(id, dto);
    return mapSingleResult(result, `Producto con ID ${id} no encontrado`);
  }

  async toggleDisponibilidad(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.toggleDisponibilidad(id, idUsuarioAuditoria);
    return mapSingleResult(result, `Producto con ID ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Producto con ID ${id} no encontrado o tiene stock activo`);
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.activar(id, idUsuarioAuditoria);
    return mapActivateResult(result, `Producto con ID ${id} no encontrado o ya activo`);
  }
}