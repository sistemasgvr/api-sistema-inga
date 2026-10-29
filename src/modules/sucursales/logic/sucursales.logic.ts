import { Injectable } from '@nestjs/common';
import {
  mapActivateResult,
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateSucursalDto, UpdateSucursalDto } from '../dto/sucursales.dto';
import { FiltroSucursalDto } from '../dto/filtros-sucursal.dto';
import { SucursalesModel } from '../models/sucursales.model';

@Injectable()
export class SucursalesLogic {
  constructor(private readonly sucursalesModel: SucursalesModel) {}

  async listar(filtros: FiltroSucursalDto, idEmpresa: number | null) {
    const result = await this.sucursalesModel.listar(filtros, idEmpresa);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.sucursalesModel.obtenerPorId(id);
    return mapSingleResult(result, `Sucursal con ID ${id} no encontrada`);
  }

  async crear(dto: CreateSucursalDto) {
    const result = await this.sucursalesModel.crear(
      dto.idEmpresa,
      dto.codigo,
      dto.nombre,
      dto.direccion,
      dto.telefono,
      dto.idDistrito,
      dto.esPrincipal,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la sucursal');
  }

  async actualizar(id: number, dto: UpdateSucursalDto) {
    const result = await this.sucursalesModel.actualizar(
      id,
      dto.idEmpresa,
      dto.codigo,
      dto.nombre,
      dto.direccion,
      dto.telefono,
      dto.idDistrito,
      dto.esPrincipal,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Sucursal con ID ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.sucursalesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Sucursal con ID ${id} no encontrada o ya desactivada`,
    );
  }

  async activar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.sucursalesModel.activar(id, idUsuarioAuditoria);
    return mapActivateResult(
      result,
      `Sucursal con ID ${id} no encontrada o ya activa`,
    );
  }
}
