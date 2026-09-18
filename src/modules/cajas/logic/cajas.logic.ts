import { Injectable } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateCajaDto, FiltroCajasDto, UpdateCajaDto } from '../dto/cajas.dto';
import { CajasModel } from '../models/cajas.model';

@Injectable()
export class CajasLogic {
  constructor(private readonly cajasModel: CajasModel) {}

  async listar(filtros: FiltroCajasDto) {
    const result = await this.cajasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.cajasModel.obtenerPorId(id);
    return mapSingleResult(result, `Caja con ID ${id} no encontrada`);
  }

  async crear(dto: CreateCajaDto) {
    const result = await this.cajasModel.crear(
      dto.id_sucursal,
      dto.codigo,
      dto.nombre,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la caja');
  }

  async actualizar(id: number, dto: UpdateCajaDto) {
    const result = await this.cajasModel.actualizar(
      id,
      dto.id_sucursal ?? null,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Caja con ID ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.cajasModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Caja con ID ${id} no encontrada o ya inactiva`);
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.cajasModel.activar(id, idUsuarioAuditoria);
    return mapActivateResult(result, `Caja con ID ${id} no encontrada o ya activa`);
  }
}
