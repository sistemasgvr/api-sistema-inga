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

  obtenerOpciones(id: number | null, codigo: string | null) {
    return this.db.callFunctionJson<AuthSingleResult<ListaConOpciones>>(
      'gen_obtener_lista_opciones',
      [id, codigo],
    );
  }
}
