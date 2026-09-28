import { Injectable } from '@nestjs/common';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { ListasModel } from '../models/listas.model';

@Injectable()
export class ListasLogic {
  constructor(private readonly model: ListasModel) {}

  listar() {
    return this.model.listar();
  }

  async obtenerOpciones(id: number) {
    return mapSingleResult(
      await this.model.obtenerOpciones(id),
      'La lista no existe o está inactiva',
    );
  }
}
