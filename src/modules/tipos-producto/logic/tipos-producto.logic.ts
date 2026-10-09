import { Injectable } from '@nestjs/common';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { CreateTipoProductoDto } from '../dto/tipos-producto.dto';
import { TiposProductoModel } from '../models/tipos-producto.model';

@Injectable()
export class TiposProductoLogic {
  constructor(private readonly model: TiposProductoModel) {}
  listar() {
    return this.model.listar();
  }
  async crear(dto: CreateTipoProductoDto) {
    return mapSingleResult(
      await this.model.crear(dto),
      'No se pudo crear el tipo de producto',
    );
  }
}
