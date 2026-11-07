import { Injectable } from '@nestjs/common';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import {
  CreateTipoProductoDto,
  UpdatePermisosTipoProductoDto,
} from '../dto/tipos-producto.dto';
import { TiposProductoModel } from '../models/tipos-producto.model';

@Injectable()
export class TiposProductoLogic {
  constructor(private readonly model: TiposProductoModel) {}
  listar(idEmpresa?: number | null) {
    return this.model.listar(idEmpresa);
  }
  async impacto(id: number, idEmpresa?: number | null) {
    return mapSingleResult(
      await this.model.impacto(id, idEmpresa),
      'Tipo de producto no encontrado',
    );
  }
  async actualizarPermisos(
    id: number,
    dto: UpdatePermisosTipoProductoDto,
    idEmpresa?: number | null,
  ) {
    return mapSingleResult(
      await this.model.actualizarPermisos(id, dto, idEmpresa),
      'Tipo de producto no encontrado',
    );
  }
  async crear(dto: CreateTipoProductoDto, idEmpresa?: number | null) {
    return mapSingleResult(
      await this.model.crear(dto, idEmpresa),
      'No se pudo crear el tipo de producto',
    );
  }
}
