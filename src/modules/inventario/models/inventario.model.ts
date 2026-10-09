import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { FiltroInventarioDto, DisponibilidadDto, CocinaFiltroDto, AvisosCocinaFiltroDto } from '../dto/inventario.dto';

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
    const funcion = tipo === 'stock' ? 'alm_buscar_stock' : 'alm_listar_kardex';
    return this.db.callFunctionJson<{ registros: Record<string, unknown>[] }>(
      funcion,
      [
        filtros.id_producto ?? null,
        filtros.id_almacen ?? null,
        filtros.limite,
        filtros.offset,
        ...(tipo === 'stock' ? [filtros.buscar ?? '', filtros.estado ?? 'todos'] : []),
      ],
    );
  }

  disponibilidad(f: DisponibilidadDto) {
    return this.db.callFunctionJson<AuthSingleResult>('prod_disponibilidad',[f.id_receta,f.id_almacen,f.cantidad,f.id_pedido_detalle ?? null]);
  }
  cocina(f: CocinaFiltroDto) {
    return this.db.callFunctionJson<{registros: unknown[]; total: number}>('ven_listar_cocina',[f.id_sucursal,f.id_estacion ?? null,f.historial==='true',f.limite,f.offset]);
  }
  avisos(f: AvisosCocinaFiltroDto) {
    return this.db.callFunctionJson<unknown[]>('ven_listar_avisos_cocina',[f.id_sucursal,f.id_estacion ?? null]);
  }
  atenderAviso(id: number, usuario: number) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_atender_aviso_cocina',[id,usuario]);
  }
  productosPreparables(sucursal:number) { return this.db.callFunctionJson<unknown[]>('prod_listar_productos',[sucursal]); }
  obtener(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'alm_obtener_movimiento',
      [id],
    );
  }
}
