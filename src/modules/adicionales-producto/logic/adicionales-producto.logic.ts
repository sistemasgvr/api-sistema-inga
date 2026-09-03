import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateAdicionalDto, UpdateAdicionalDto } from '../dto/adicionales-producto.dto';
import { AdicionalesProductoModel } from '../models/adicionales-producto.model';

@Injectable()
export class AdicionalesProductoLogic {
  constructor(private readonly adicionalesModel: AdicionalesProductoModel) {}

  async listarPorProducto(idProducto: number) {
    return await this.adicionalesModel.listarPorProducto(idProducto);
  }

  async obtenerPorId(id: number) {
    const result = await this.adicionalesModel.obtenerPorId(id);
    return mapSingleResult(result, `Adicional con ID ${id} no encontrado`);
  }

  async crear(idProducto: number, dto: CreateAdicionalDto) {
    const result = await this.adicionalesModel.crear(idProducto, dto);
    return mapSingleResult(result, 'No se pudo crear el adicional');
  }

  async actualizar(id: number, dto: UpdateAdicionalDto) {
    const result = await this.adicionalesModel.actualizar(id, dto);
    return mapSingleResult(result, `Adicional con ID ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.adicionalesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Adicional con ID ${id} no encontrado o ya inactivo`);
  }
}