import { Injectable } from '@nestjs/common';
import { mapListResult } from '../../../common/helpers/auth-response.helper';
import { FiltroPermisoDto } from '../dto/filtros-permiso.dto';
import { PermisosModel } from '../models/permisos.model';

@Injectable()
export class PermisosLogic {
  constructor(private readonly permisosModel: PermisosModel) {}

  async listar(filtros: FiltroPermisoDto) {
    const result = await this.permisosModel.listar(filtros);
    return mapListResult(result, filtros);
  }
}