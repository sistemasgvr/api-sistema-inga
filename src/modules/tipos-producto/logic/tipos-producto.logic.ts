import { Injectable } from '@nestjs/common';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { CreateTipoProductoDto } from '../dto/tipos-producto.dto';
import { TiposProductoModel } from '../models/tipos-producto.model';

@Injectable()
export class TiposProductoLogic {
  constructor(private readonly model: TiposProductoModel) {}
  listar(idEmpresa?: number | null) {
    return this.model.listar(idEmpresa);
  }
  async crear(dto: CreateTipoProductoDto, idEmpresa?: number | null) {
    return mapSingleResult(
      await this.model.crear(dto, idEmpresa),
      'No se pudo crear el tipo de producto',
    );
  }
}
