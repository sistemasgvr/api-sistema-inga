import { Injectable } from '@nestjs/common';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { GeneralListasModel } from '../models/general-listas.model';

@Injectable()
export class GeneralListasLogic {
  constructor(private readonly listasModel: GeneralListasModel) {}

  async obtenerOpcionesPorLista(codigoLista: string) {
    const result = await this.listasModel.obtenerOpcionesPorLista(codigoLista);

    return mapSingleResult(
      result,
      `No se encontraron opciones para el catálogo: ${codigoLista}`,
    );
  }
}
