import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { FiltroInventarioDto } from '../dto/inventario.dto';

export type OperacionInventario =
  'alm_registrar' | 'alm_confirmar' | 'alm_cancelar' | 'prod_preparar';

@Injectable()
export class InventarioModel {
  constructor(private readonly db: DatabaseService) {}

  ejecutar(
    funcion: OperacionInventario,
    datos: object | number,
    usuario: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(funcion, [
      typeof datos === 'number' ? datos : JSON.stringify(datos),
      usuario,
    ]);
  }

  listar(tipo: 'stock' | 'kardex', filtros: FiltroInventarioDto) {
    const funcion = tipo === 'stock' ? 'alm_listar_stock' : 'alm_listar_kardex';
    return this.db.callFunctionJson<{ registros: Record<string, unknown>[] }>(
      funcion,
      [
        filtros.id_producto ?? null,
        filtros.id_almacen ?? null,
        filtros.limite,
        filtros.offset,
      ],
    );
  }

  obtener(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'alm_obtener_movimiento',
      [id],
    );
  }
}
