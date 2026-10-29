import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAdicionalDto,
  UpdateAdicionalDto,
} from '../dto/adicionales-producto.dto';
import { AdicionalesProductoModel } from '../models/adicionales-producto.model';

@Injectable()
export class AdicionalesProductoLogic {
  constructor(private readonly adicionalesModel: AdicionalesProductoModel) {}

  async listarPorProducto(idProducto: number, idEmpresa?: number | null) {
    return await this.adicionalesModel.listarPorProducto(idProducto, idEmpresa);
  }

  async obtenerPorId(id: number, idEmpresa?: number | null) {
    const result = await this.adicionalesModel.obtenerPorId(id, idEmpresa);
    return mapSingleResult(result, `Adicional con ID ${id} no encontrado`);
  }

  async crear(
    idProducto: number,
    dto: CreateAdicionalDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.adicionalesModel.crear(
      idProducto,
      dto,
      idEmpresa,
    );
    return mapSingleResult(result, 'No se pudo crear el adicional');
  }

  async actualizar(
    id: number,
    dto: UpdateAdicionalDto,
    idEmpresa?: number | null,
  ) {
    const result = await this.adicionalesModel.actualizar(id, dto, idEmpresa);
    return mapSingleResult(result, `Adicional con ID ${id} no encontrado`);
  }

  async eliminar(
    id: number,
    idUsuarioAuditoria?: number,
    idEmpresa?: number | null,
  ) {
    const result = await this.adicionalesModel.eliminar(
      id,
      idUsuarioAuditoria,
      idEmpresa,
    );
    return mapDeleteResult(
      result,
      `Adicional con ID ${id} no encontrado o ya inactivo`,
    );
  }
}
