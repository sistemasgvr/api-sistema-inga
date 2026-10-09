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

  obtenerOpciones(id: number, tipo?: number) {
    return this.db.callFunctionJson<AuthSingleResult<ListaConOpciones>>(
      tipo === undefined ? 'gen_obtener_opciones_lista' : 'gen_filtrar_opciones_lista',
      tipo === undefined ? [id] : [id, tipo],
    );
  }
}
