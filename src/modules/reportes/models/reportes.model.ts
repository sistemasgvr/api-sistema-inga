import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';

/**
 * Consultas de solo lectura para el dashboard y la reportería: funciones rep_*
 * de database_sql/funciones/reportes. Salvo rep_stock, todas reciben
 * (desde, hasta, id_empresa, id_sucursal) y devuelven filas en JSON.
 *
 * Criterios compartidos con el resto del sistema:
 * - Venta = pedido cobrado (estado_pedido 4) y vigente, fechado por su cobro en
 *   Lima, igual que `ven_listar_ventas` (rep_ventas_periodo).
 * - La empresa es la de la sesión: suma todas sus sucursales y nada de otra
 *   empresa; id_sucursal es un filtro opcional dentro de esa empresa.
 * - Las cuentas por cobrar y por pagar son de la empresa: la sucursal no filtra.
 */
export type FiltroPeriodo = {
  fecha_desde: string;
  fecha_hasta: string;
  id_empresa: number | null;
  id_sucursal?: number | null;
};

type Fila = Record<string, unknown>;

@Injectable()
export class ReportesModel {
  constructor(private readonly db: DatabaseService) {}

  private filas<T = Fila[]>(funcion: string, f: FiltroPeriodo) {
    return this.db.callFunctionJson<T>(funcion, [
      f.fecha_desde,
      f.fecha_hasta,
      f.id_empresa,
      f.id_sucursal ?? null,
    ]);
  }

  resumenVentas(f: FiltroPeriodo) {
    return this.filas<Fila>('rep_resumen_ventas', f);
  }

  productosVendidos(f: FiltroPeriodo) {
    return this.filas('rep_productos_vendidos', f);
  }

  ventasPorDia(f: FiltroPeriodo) {
    return this.filas('rep_ventas_por_dia', f);
  }

  ventasPorHora(f: FiltroPeriodo) {
    return this.filas('rep_ventas_por_hora', f);
  }

  ventasPorDiaSemana(f: FiltroPeriodo) {
    return this.filas('rep_ventas_por_dia_semana', f);
  }

  ventasPorTipo(f: FiltroPeriodo) {
    return this.filas('rep_ventas_por_tipo', f);
  }

  ventasPorMedio(f: FiltroPeriodo) {
    return this.filas('rep_ventas_por_medio', f);
  }

  ventasPorMozo(f: FiltroPeriodo) {
    return this.filas('rep_ventas_por_mozo', f);
  }

  listadoVentas(f: FiltroPeriodo) {
    return this.filas('rep_listado_ventas', f);
  }

  gastosDiariosPorDia(f: FiltroPeriodo) {
    return this.filas('rep_gastos_diarios_por_dia', f);
  }

  gastosDiariosPorItem(f: FiltroPeriodo) {
    return this.filas('rep_gastos_diarios_por_item', f);
  }

  gastosAdministrativos(f: FiltroPeriodo) {
    return this.filas('rep_gastos_administrativos', f);
  }

  pagosPlanilla(f: FiltroPeriodo) {
    return this.filas('rep_pagos_planilla', f);
  }

  turnos(f: FiltroPeriodo) {
    return this.filas('rep_turnos', f);
  }

  movimientosCaja(f: FiltroPeriodo) {
    return this.filas('rep_movimientos_caja', f);
  }

  cuentasPorCobrar(f: FiltroPeriodo) {
    return this.filas('rep_cuentas_por_cobrar', f);
  }

  cuentasPorPagar(f: FiltroPeriodo) {
    return this.filas('rep_cuentas_por_pagar', f);
  }

  /** Foto del stock al momento de la consulta: el rango de fechas no aplica. */
  stock(f: FiltroPeriodo) {
    return this.db.callFunctionJson<Fila[]>('rep_stock', [
      f.id_empresa,
      f.id_sucursal ?? null,
    ]);
  }

  movimientosInventario(f: FiltroPeriodo) {
    return this.filas('rep_movimientos_inventario', f);
  }
}
