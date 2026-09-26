import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';

export type AccionPedido =
  | 'abrir'
  | 'agregar_item'
  | 'editar_item'
  | 'anular_item'
  | 'comandar'
  | 'estado'
  | 'anular';

@Injectable()
export class PedidoModel {
  constructor(private readonly db: DatabaseService) {}

  obtener(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_obtener_pedido', [
      id,
    ]);
  }

  ejecutar(
    accion: AccionPedido,
    id: number | null,
    item: number | null,
    datos: object,
    usuario: number,
  ) {
    // Cada llamada SQL constituye una transacción: cualquier error revierte toda la operación.
    return this.db.callFunctionJson<AuthSingleResult>(`ven_pedido_${accion}`, [
      id,
      item,
      JSON.stringify(datos),
      usuario,
    ]);
  }
}
