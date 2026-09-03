import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateEstacionDto,
  FiltroEstacionesDto,
  UpdateEstacionDto,
} from '../dto/estaciones.dto';
import { EstacionesModel } from '../models/estaciones.model';

@Injectable()
export class EstacionesLogic {
  constructor(private readonly estacionesModel: EstacionesModel) {}

  async listar(filtros: FiltroEstacionesDto) {
    const result = await this.estacionesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.estacionesModel.obtenerPorId(id);
    return mapSingleResult(result, `Estación con ID ${id} no encontrada`);
  }

  async crear(dto: CreateEstacionDto) {
    const result = await this.estacionesModel.crear(
      dto.id_sucursal,
      dto.codigo,
      dto.nombre,
      dto.tipo_estacion,
      dto.impresora_nombre ?? null,
      dto.impresora_ip ?? null,
      dto.usa_kds ?? false,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la estación');
  }

  async actualizar(id: number, dto: UpdateEstacionDto) {
    const result = await this.estacionesModel.actualizar(
      id,
      dto.id_sucursal ?? null,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.tipo_estacion ?? null,
      dto.impresora_nombre ?? null,
      dto.impresora_ip ?? null,
      dto.usa_kds ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Estación con ID ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.estacionesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Estación con ID ${id} no encontrada o ya inactiva`);
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.estacionesModel.activar(id, idUsuarioAuditoria);
    
    if (!result || (result as any).activado === false) {
      return { message: "La estación ya se encontraba activa o fue actualizada", data: { id } };
    }

    return result;
  }
}