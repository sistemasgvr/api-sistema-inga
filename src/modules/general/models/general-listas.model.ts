import { Injectable } from '@nestjs/common';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { OpcionCatalogoDto } from '../dto/general-listas.dto';

@Injectable()
export class GeneralListasModel {
  constructor(private readonly db: DatabaseService) {}

  obtenerOpcionesPorLista(codigoLista: string) {
    return this.db.callFunctionJson<AuthSingleResult<OpcionCatalogoDto[]>>(
      'gen_obtener_opciones_lista',
      [codigoLista],
    );
  }
}