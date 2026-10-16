import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../../database/database.service';

/**
 * Consultas de solo lectura para el dashboard y la reportería.
 *
 * Salvo las indicadas, reciben los mismos tres parámetros, en este orden:
 *   $1 fecha desde (DATE, día de Lima)
 *   $2 fecha hasta (DATE, día de Lima)
 *   $3 id_sucursal (BIGINT o NULL = todas)
 *
 * Criterios compartidos con el resto del sistema:
 * - Venta = pedido cobrado (estado_pedido 4) y vigente, fechado por su cobro en
 *   Lima, igual que `ven_listar_ventas`.
 * - Una línea vendida descuenta lo cancelado y excluye las anuladas
 *   (tipo_linea 3); la cortesía (2) no factura pero sí cuesta.
 * - El costo unitario sale de `pro_costo_unitario_insumo`: costo de la receta
 *   vigente o, si no tiene receta, el costo promedio del almacén. Es el costo
 *   ACTUAL del producto, no el del día de la venta.
 * - Los gastos sin sucursal (columna nula) se consideran de toda la empresa y
 *   entran en cualquier filtro de sucursal.
 *
 * Los montos salen como float8 para que el JSON lleve números y no texto.
 */

const VENTAS = `
  ventas AS (
    SELECT p.id, p.id_sucursal, p.id_mozo, p.id_mesa, p.codigo, p.tipo_pedido,
      p.num_comensales, p.monto_total, p.monto_igv, p.monto_descuento, p.tasa_igv,
      p.fecha_cierre,
      p.fecha_cierre AT TIME ZONE 'America/Lima' AS fecha_lima
    FROM ven_pedido p
    WHERE p.estado = 1 AND p.estado_pedido = 4
      AND (p.fecha_cierre AT TIME ZONE 'America/Lima')::DATE BETWEEN $1::DATE AND $2::DATE
      AND ($3::BIGINT IS NULL OR p.id_sucursal = $3::BIGINT)
  )`;

const MEDIOS = `
  medios AS (
    SELECT o.valor_entero AS medio_pago, o.nombre
    FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = 'MEDIO_PAGO'
  )`;

const SQL_RESUMEN_VENTAS = `
  WITH ${VENTAS}
  SELECT count(*)::INT AS cantidad,
    COALESCE(sum(monto_total), 0)::FLOAT8 AS total,
    COALESCE(sum(monto_igv), 0)::FLOAT8 AS igv,
    COALESCE(sum(monto_descuento), 0)::FLOAT8 AS descuentos,
    COALESCE(sum(num_comensales), 0)::INT AS comensales
  FROM ventas`;

const SQL_PRODUCTOS_VENDIDOS = `
  WITH ${VENTAS},
  lineas AS (
    SELECT d.id_producto, d.tipo_linea, (d.cantidad - d.cantidad_cancelada) AS cantidad,
      CASE WHEN d.afecto_igv THEN d.monto_subtotal
        ELSE round(d.monto_subtotal * (1 + v.tasa_igv / 100), 2) END AS bruto,
      CASE WHEN d.afecto_igv THEN round(d.monto_subtotal / (1 + v.tasa_igv / 100), 2)
        ELSE d.monto_subtotal END AS neto
    FROM ven_pedido_detalle d JOIN ventas v ON v.id = d.id_pedido
    WHERE d.estado = 1 AND d.tipo_linea IN (1, 2) AND d.cantidad > d.cantidad_cancelada
  ), agrupado AS (
    SELECT id_producto, sum(cantidad) AS cantidad,
      COALESCE(sum(cantidad) FILTER (WHERE tipo_linea = 2), 0) AS cortesias,
      sum(bruto) AS monto, sum(neto) AS monto_neto
    FROM lineas GROUP BY id_producto
  )
  SELECT a.id_producto::INT AS id_producto, p.nombre, COALESCE(c.nombre, 'Sin categoría') AS categoria,
    a.cantidad::FLOAT8 AS cantidad, a.cortesias::FLOAT8 AS cortesias,
    a.monto::FLOAT8 AS monto, a.monto_neto::FLOAT8 AS monto_neto,
    pro_costo_unitario_insumo(a.id_producto)::FLOAT8 AS costo_unitario
  FROM agrupado a
  JOIN pro_producto p ON p.id = a.id_producto
  LEFT JOIN pro_subcategoria s ON s.id = p.id_subcategoria
  LEFT JOIN pro_categoria c ON c.id = s.id_categoria
  ORDER BY a.cantidad DESC, a.monto DESC`;

const SQL_VENTAS_POR_DIA = `
  WITH ${VENTAS}
  SELECT to_char(fecha_lima, 'YYYY-MM-DD') AS fecha, count(*)::INT AS cantidad,
    sum(monto_total)::FLOAT8 AS total, sum(monto_total - monto_igv)::FLOAT8 AS neto
  FROM ventas GROUP BY 1 ORDER BY 1`;

const SQL_VENTAS_POR_HORA = `
  WITH ${VENTAS}
  SELECT extract(HOUR FROM fecha_lima)::INT AS hora, count(*)::INT AS cantidad,
    sum(monto_total)::FLOAT8 AS total
  FROM ventas GROUP BY 1 ORDER BY 1`;

const SQL_VENTAS_POR_DIA_SEMANA = `
  WITH ${VENTAS}
  SELECT extract(ISODOW FROM fecha_lima)::INT AS dia, count(*)::INT AS cantidad,
    sum(monto_total)::FLOAT8 AS total
  FROM ventas GROUP BY 1 ORDER BY 1`;

const SQL_VENTAS_POR_TIPO = `
  WITH ${VENTAS}
  SELECT tipo_pedido::INT AS tipo_pedido, count(*)::INT AS cantidad,
    sum(monto_total)::FLOAT8 AS total, COALESCE(sum(num_comensales), 0)::INT AS comensales
  FROM ventas GROUP BY 1 ORDER BY 1`;

const SQL_VENTAS_POR_MEDIO = `
  WITH ${VENTAS}, ${MEDIOS}
  SELECT g.medio_pago::INT AS medio_pago, COALESCE(m.nombre, g.medio_pago::TEXT) AS nombre,
    count(*)::INT AS cantidad, sum(g.monto)::FLOAT8 AS total
  FROM ven_pago g JOIN ventas v ON v.id = g.id_pedido
  LEFT JOIN medios m ON m.medio_pago = g.medio_pago
  WHERE g.estado = 1
  GROUP BY g.medio_pago, m.nombre ORDER BY g.medio_pago`;

// Mesas atendidas = pedidos de mesa cobrados (cada apertura de mesa es una
// atención, aunque se repita la misma mesa en el día).
const SQL_VENTAS_POR_MOZO = `
  WITH ${VENTAS}
  SELECT v.id_mozo::INT AS id_mozo,
    COALESCE(NULLIF(trim(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username, 'Sin nombre') AS nombre,
    count(*)::INT AS cantidad, sum(v.monto_total)::FLOAT8 AS total,
    count(*) FILTER (WHERE v.id_mesa IS NOT NULL)::INT AS mesas,
    COALESCE(sum(v.num_comensales), 0)::INT AS comensales
  FROM ventas v LEFT JOIN auth_usuario_datos u ON u.id = v.id_mozo
  GROUP BY v.id_mozo, u.nombres, u.apellidos, u.username ORDER BY total DESC`;

const SQL_LISTADO_VENTAS = `
  WITH ${VENTAS}, ${MEDIOS}
  SELECT v.id::INT AS id, v.codigo, to_char(v.fecha_lima, 'YYYY-MM-DD HH24:MI') AS fecha,
    v.tipo_pedido::INT AS tipo_pedido,
    (SELECT m.codigo FROM ven_mesa m WHERE m.id = v.id_mesa) AS mesa,
    (SELECT COALESCE(NULLIF(trim(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username)
      FROM auth_usuario_datos u WHERE u.id = v.id_mozo) AS mozo,
    v.num_comensales::INT AS comensales, v.monto_total::FLOAT8 AS total,
    COALESCE((SELECT string_agg(COALESCE(md.nombre, g.medio_pago::TEXT), ', ' ORDER BY g.id)
      FROM ven_pago g LEFT JOIN medios md ON md.medio_pago = g.medio_pago
      WHERE g.id_pedido = v.id AND g.estado = 1), '') AS medios
  FROM ventas v ORDER BY v.fecha_cierre DESC, v.id DESC`;

/* --------------------------------- Gastos --------------------------------- */

const SQL_GASTOS_DIARIOS_POR_DIA = `
  SELECT to_char(g.fecha_gasto, 'YYYY-MM-DD') AS fecha,
    sum(g.total_efectivo)::FLOAT8 AS efectivo, sum(g.total_yape)::FLOAT8 AS yape,
    sum(g.total_credito)::FLOAT8 AS credito, sum(g.total_general)::FLOAT8 AS total
  FROM gdo_gasto_dia g
  WHERE g.estado = 1 AND g.fecha_gasto BETWEEN $1::DATE AND $2::DATE
    AND ($3::BIGINT IS NULL OR g.id_sucursal IS NULL OR g.id_sucursal = $3::BIGINT)
  GROUP BY g.fecha_gasto ORDER BY g.fecha_gasto`;

const SQL_GASTOS_DIARIOS_POR_ITEM = `
  SELECT COALESCE(i.nombre, p.nombre, 'Sin nombre') AS item,
    COALESCE(gc.nombre, 'Compra a inventario') AS categoria,
    count(*)::INT AS compras, sum(d.subtotal)::FLOAT8 AS total,
    COALESCE(sum(d.subtotal) FILTER (WHERE d.forma_pago = 3), 0)::FLOAT8 AS credito
  FROM gdo_gasto_detalle d
  JOIN gdo_gasto_dia g ON g.id = d.id_gasto_dia
  LEFT JOIN gdo_insumo i ON i.id = d.id_insumo
  LEFT JOIN gdo_categoria gc ON gc.id = i.id_categoria
  LEFT JOIN pro_producto p ON p.id = d.id_producto
  WHERE d.estado = 1 AND g.estado = 1 AND g.fecha_gasto BETWEEN $1::DATE AND $2::DATE
    AND ($3::BIGINT IS NULL OR g.id_sucursal IS NULL OR g.id_sucursal = $3::BIGINT)
  GROUP BY 1, 2 ORDER BY total DESC`;

const SQL_GASTOS_ADMINISTRATIVOS = `
  WITH ${MEDIOS}
  SELECT g.id::INT AS id, to_char(g.fecha_gasto, 'YYYY-MM-DD') AS fecha,
    COALESCE(cp.nombre, c.nombre) AS categoria,
    CASE WHEN cp.id IS NOT NULL THEN c.nombre END AS subcategoria,
    c.tipo_gasto::INT AS tipo_gasto, g.concepto,
    g.medio_pago::INT AS medio_pago, COALESCE(m.nombre, g.medio_pago::TEXT) AS medio,
    g.num_comprobante, g.monto::FLOAT8 AS monto
  FROM gad_gasto g
  JOIN gad_categoria c ON c.id = g.id_categoria
  LEFT JOIN gad_categoria cp ON cp.id = c.id_categoria_padre
  LEFT JOIN medios m ON m.medio_pago = g.medio_pago
  WHERE g.estado = 1 AND g.fecha_gasto BETWEEN $1::DATE AND $2::DATE
    AND ($3::BIGINT IS NULL OR g.id_sucursal IS NULL OR g.id_sucursal = $3::BIGINT)
  ORDER BY g.fecha_gasto DESC, g.id DESC`;

const SQL_PLANILLA = `
  WITH ${MEDIOS}
  SELECT pp.id::INT AS id, to_char(pp.fecha_pago, 'YYYY-MM-DD') AS fecha,
    pp.id_trabajador::INT AS id_trabajador,
    trim(concat_ws(' ', t.nombres, t.apellidos)) AS trabajador, t.puesto,
    pp.anio::INT AS anio, pp.mes::INT AS mes, pp.quincena::INT AS quincena,
    pp.medio_pago::INT AS medio_pago, COALESCE(m.nombre, pp.medio_pago::TEXT) AS medio,
    pp.monto::FLOAT8 AS monto, pp.observacion
  FROM pla_pago pp
  JOIN pla_trabajador t ON t.id = pp.id_trabajador
  LEFT JOIN medios m ON m.medio_pago = pp.medio_pago
  WHERE pp.estado = 1 AND pp.fecha_pago BETWEEN $1::DATE AND $2::DATE
    AND ($3::BIGINT IS NULL OR t.id_sucursal IS NULL OR t.id_sucursal = $3::BIGINT)
  ORDER BY pp.fecha_pago DESC, trabajador`;

/* ---------------------------------- Caja ---------------------------------- */

const SQL_TURNOS = `
  SELECT t.id::INT AS id, cj.nombre AS caja,
    COALESCE(NULLIF(trim(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username) AS cajero,
    to_char(t.fecha_apertura AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI') AS fecha_apertura,
    to_char(t.fecha_cierre AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI') AS fecha_cierre,
    t.estado_turno::INT AS estado_turno,
    t.monto_apertura::FLOAT8 AS monto_apertura,
    t.monto_cierre_declarado::FLOAT8 AS monto_declarado,
    t.monto_diferencia::FLOAT8 AS monto_diferencia,
    caj_calcular_totales_turno(t.id) AS totales
  FROM caj_turno t
  JOIN caj_caja cj ON cj.id = t.id_caja
  LEFT JOIN auth_usuario_datos u ON u.id = t.id_cajero
  WHERE t.estado = 1
    AND (t.fecha_apertura AT TIME ZONE 'America/Lima')::DATE BETWEEN $1::DATE AND $2::DATE
    AND ($3::BIGINT IS NULL OR cj.id_sucursal = $3::BIGINT)
  ORDER BY t.fecha_apertura DESC`;

const SQL_MOVIMIENTOS_CAJA = `
  SELECT m.id::INT AS id,
    to_char(m.fecha_creacion AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI') AS fecha,
    cj.nombre AS caja, m.tipo_movimiento::INT AS tipo_movimiento,
    m.monto::FLOAT8 AS monto, m.motivo,
    COALESCE(NULLIF(trim(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username) AS usuario
  FROM caj_movimiento m
  JOIN caj_turno t ON t.id = m.id_turno
  JOIN caj_caja cj ON cj.id = t.id_caja
  LEFT JOIN auth_usuario_datos u ON u.id = m.id_usuario_creacion
  WHERE m.estado = 1
    AND (m.fecha_creacion AT TIME ZONE 'America/Lima')::DATE BETWEEN $1::DATE AND $2::DATE
    AND ($3::BIGINT IS NULL OR cj.id_sucursal = $3::BIGINT)
  ORDER BY m.fecha_creacion DESC`;

/* -------------------------------- Cuentas --------------------------------- */

// Saldo actual (vistas del sistema) más lo movido en el período. Entran las
// personas con deuda o con algún movimiento en el rango. Las cuentas son de la
// empresa: no se filtran por sucursal. Parámetros: $1 desde, $2 hasta.
const SQL_CXC = `
  WITH periodo AS (
    SELECT id_persona,
      COALESCE(sum(monto) FILTER (WHERE tipo_movimiento = 1), 0) AS cargos,
      COALESCE(sum(monto) FILTER (WHERE tipo_movimiento = 2), 0) AS abonos,
      COALESCE(sum(monto) FILTER (WHERE tipo_movimiento = 3), 0) AS ajustes
    FROM cxc_movimiento
    WHERE estado = 1
      AND (fecha_creacion AT TIME ZONE 'America/Lima')::DATE BETWEEN $1::DATE AND $2::DATE
    GROUP BY id_persona
  )
  SELECT s.id_persona::INT AS id_persona, s.nombre, s.num_documento, s.convenio,
    COALESCE(s.saldo, 0)::FLOAT8 AS saldo,
    COALESCE(p.cargos, 0)::FLOAT8 AS cargos_periodo,
    COALESCE(p.abonos, 0)::FLOAT8 AS abonos_periodo,
    COALESCE(p.ajustes, 0)::FLOAT8 AS ajustes_periodo
  FROM vw_cxc_saldo_persona s
  LEFT JOIN periodo p ON p.id_persona = s.id_persona
  WHERE COALESCE(s.saldo, 0) <> 0 OR p.id_persona IS NOT NULL
  ORDER BY s.saldo DESC NULLS LAST, s.nombre`;

const SQL_CXP = `
  WITH periodo AS (
    SELECT id_persona,
      COALESCE(sum(monto) FILTER (WHERE tipo_movimiento = 1), 0) AS cargos,
      COALESCE(sum(monto) FILTER (WHERE tipo_movimiento = 2), 0) AS abonos,
      COALESCE(sum(monto) FILTER (WHERE tipo_movimiento = 3), 0) AS ajustes
    FROM cxp_movimiento
    WHERE estado = 1 AND fecha_movimiento BETWEEN $1::DATE AND $2::DATE
    GROUP BY id_persona
  )
  SELECT s.id_persona::INT AS id_persona, s.nombre, s.num_documento,
    COALESCE(s.saldo, 0)::FLOAT8 AS saldo,
    COALESCE(p.cargos, 0)::FLOAT8 AS cargos_periodo,
    COALESCE(p.abonos, 0)::FLOAT8 AS abonos_periodo,
    COALESCE(p.ajustes, 0)::FLOAT8 AS ajustes_periodo
  FROM vw_cxp_saldo_proveedor s
  LEFT JOIN periodo p ON p.id_persona = s.id_persona
  WHERE COALESCE(s.saldo, 0) <> 0 OR p.id_persona IS NOT NULL
  ORDER BY s.saldo DESC NULLS LAST, s.nombre`;

/* ------------------------------- Inventario ------------------------------- */

// Foto del stock al momento de la consulta: el rango de fechas no aplica.
// Único parámetro: $1 id_sucursal.
const SQL_STOCK = `
  SELECT s.id::INT AS id, a.nombre AS almacen, p.nombre AS producto,
    COALESCE(u.simbolo, u.nombre) AS unidad,
    s.stock_actual::FLOAT8 AS stock_actual, s.stock_reservado::FLOAT8 AS stock_reservado,
    s.stock_minimo::FLOAT8 AS stock_minimo, s.costo_promedio::FLOAT8 AS costo_promedio,
    round(s.stock_actual * s.costo_promedio, 2)::FLOAT8 AS valorizado,
    (p.controla_stock AND s.stock_minimo > 0 AND s.stock_actual <= s.stock_minimo) AS bajo_minimo
  FROM alm_producto_stock s
  JOIN gen_almacen a ON a.id = s.id_almacen
  JOIN pro_producto p ON p.id = s.id_producto
  LEFT JOIN pro_unidad_medida u ON u.id = p.id_unidad_medida
  WHERE s.estado = 1 AND p.estado = 1 AND a.estado = 1
    AND ($1::BIGINT IS NULL OR a.id_sucursal = $1::BIGINT)
  ORDER BY a.nombre, p.nombre`;

// Movimientos confirmados del período, agrupados por tipo y motivo.
const SQL_MOVIMIENTOS_INVENTARIO = `
  SELECT k.tipo_movimiento, k.motivo, count(DISTINCT k.id_movimiento)::INT AS movimientos,
    COALESCE(sum(k.entrada * k.costo_unitario), 0)::FLOAT8 AS valor_entradas,
    COALESCE(sum(k.salida * k.costo_unitario), 0)::FLOAT8 AS valor_salidas
  FROM vw_alm_kardex k
  JOIN gen_almacen a ON a.id = k.id_almacen
  WHERE (COALESCE(k.fecha_confirmacion, k.fecha_movimiento) AT TIME ZONE 'America/Lima')::DATE
      BETWEEN $1::DATE AND $2::DATE
    AND ($3::BIGINT IS NULL OR a.id_sucursal = $3::BIGINT)
  GROUP BY k.tipo_movimiento, k.motivo ORDER BY k.tipo_movimiento, k.motivo`;

export type FiltroPeriodo = {
  fecha_desde: string;
  fecha_hasta: string;
  id_sucursal?: number | null;
};

@Injectable()
export class ReportesModel {
  constructor(private readonly db: DatabaseService) {}

  private filas<T extends QueryResultRow>(sql: string, f: FiltroPeriodo) {
    return this.consultar<T>(sql, [
      f.fecha_desde,
      f.fecha_hasta,
      f.id_sucursal ?? null,
    ]);
  }

  private async consultar<T extends QueryResultRow>(
    sql: string,
    params: unknown[],
  ) {
    const result = await this.db.query<T>(sql, params);
    return result.rows;
  }

  resumenVentas(f: FiltroPeriodo) {
    return this.filas(SQL_RESUMEN_VENTAS, f).then((r) => r[0]);
  }

  productosVendidos(f: FiltroPeriodo) {
    return this.filas(SQL_PRODUCTOS_VENDIDOS, f);
  }

  ventasPorDia(f: FiltroPeriodo) {
    return this.filas(SQL_VENTAS_POR_DIA, f);
  }

  ventasPorHora(f: FiltroPeriodo) {
    return this.filas(SQL_VENTAS_POR_HORA, f);
  }

  ventasPorDiaSemana(f: FiltroPeriodo) {
    return this.filas(SQL_VENTAS_POR_DIA_SEMANA, f);
  }

  ventasPorTipo(f: FiltroPeriodo) {
    return this.filas(SQL_VENTAS_POR_TIPO, f);
  }

  ventasPorMedio(f: FiltroPeriodo) {
    return this.filas(SQL_VENTAS_POR_MEDIO, f);
  }

  ventasPorMozo(f: FiltroPeriodo) {
    return this.filas(SQL_VENTAS_POR_MOZO, f);
  }

  listadoVentas(f: FiltroPeriodo) {
    return this.filas(SQL_LISTADO_VENTAS, f);
  }

  gastosDiariosPorDia(f: FiltroPeriodo) {
    return this.filas(SQL_GASTOS_DIARIOS_POR_DIA, f);
  }

  gastosDiariosPorItem(f: FiltroPeriodo) {
    return this.filas(SQL_GASTOS_DIARIOS_POR_ITEM, f);
  }

  gastosAdministrativos(f: FiltroPeriodo) {
    return this.filas(SQL_GASTOS_ADMINISTRATIVOS, f);
  }

  pagosPlanilla(f: FiltroPeriodo) {
    return this.filas(SQL_PLANILLA, f);
  }

  turnos(f: FiltroPeriodo) {
    return this.filas(SQL_TURNOS, f);
  }

  movimientosCaja(f: FiltroPeriodo) {
    return this.filas(SQL_MOVIMIENTOS_CAJA, f);
  }

  cuentasPorCobrar(f: FiltroPeriodo) {
    return this.consultar(SQL_CXC, [f.fecha_desde, f.fecha_hasta]);
  }

  cuentasPorPagar(f: FiltroPeriodo) {
    return this.consultar(SQL_CXP, [f.fecha_desde, f.fecha_hasta]);
  }

  stock(idSucursal?: number | null) {
    return this.consultar(SQL_STOCK, [idSucursal ?? null]);
  }

  movimientosInventario(f: FiltroPeriodo) {
    return this.filas(SQL_MOVIMIENTOS_INVENTARIO, f);
  }
}
