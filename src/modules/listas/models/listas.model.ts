import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { ListaConOpciones, ListaItem } from '../dto/listas.dto';

@Injectable()
export class ListasModel {
  constructor(private readonly db: DatabaseService) {}

  listar() {
    return this.db.callFunctionJson<ListaItem[]>('gen_listar_listas');
  }

  obtenerOpciones(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<ListaConOpciones>>(
      'gen_obtener_opciones_lista',
      [id],
    );
  }
}
