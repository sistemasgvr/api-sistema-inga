import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAlmacenDto,
  FiltroAlmacenesDto,
  UpdateAlmacenDto,
} from '../dto/almacenes.dto';
import { AlmacenesModel } from '../models/almacenes.model';

@Injectable()
export class AlmacenesLogic {
  constructor(private readonly almacenModel: AlmacenesModel) {}

  async listar(filtros: FiltroAlmacenesDto) {
    const result = await this.almacenModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.almacenModel.obtenerPorId(id);
    return mapSingleResult(result, `Almacén con ID ${id} no encontrado`);
  }

  async crear(dto: CreateAlmacenDto) {
    const result = await this.almacenModel.crear(
      dto.id_sucursal,
      dto.codigo,
      dto.nombre,
      dto.descripcion ?? null,
      dto.tipo_almacen,
      dto.es_principal ?? false,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el almacén');
  }

  async actualizar(id: number, dto: UpdateAlmacenDto) {
    const result = await this.almacenModel.actualizar(
      id,
      dto.id_sucursal ?? null,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.tipo_almacen ?? null,
      dto.es_principal ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Almacén con ID ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.almacenModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Almacén con ID ${id} no encontrado o ya inactivo`);
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.almacenModel.activar(id, idUsuarioAuditoria);
    
    if (!result || (result as any).activado === false) {
      return { message: "El almacén ya se encontraba activo o fue actualizado", data: { id } };
    }

    return result;
  }
}