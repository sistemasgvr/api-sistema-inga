-- Productos vendidos: descuenta lo cancelado y excluye líneas anuladas (tipo 3); la
-- cortesía (2) no factura pero sí cuesta. costo_unitario es el costo ACTUAL.
DROP FUNCTION IF EXISTS rep_productos_vendidos(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_productos_vendidos(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    WITH ventas AS (
        SELECT * FROM rep_ventas_periodo(p_fecha_desde, p_fecha_hasta, p_id_empresa, p_id_sucursal)
    ),
    lineas AS (
        SELECT
            d.id_producto,
            d.tipo_linea,
            (d.cantidad - d.cantidad_cancelada) AS cantidad,
            CASE WHEN d.afecto_igv THEN d.monto_subtotal
                 ELSE round(d.monto_subtotal * (1 + v.tasa_igv / 100), 2) END AS bruto,
            CASE WHEN d.afecto_igv THEN round(d.monto_subtotal / (1 + v.tasa_igv / 100), 2)
                 ELSE d.monto_subtotal END AS neto
        FROM ven_pedido_detalle d
        JOIN ventas v ON v.id = d.id_pedido
        WHERE d.estado = 1
          AND d.tipo_linea IN (1, 2)
          AND d.cantidad > d.cantidad_cancelada
    ),
    agrupado AS (
        SELECT
            id_producto,
            SUM(cantidad) AS cantidad,
            COALESCE(SUM(cantidad) FILTER (WHERE tipo_linea = 2), 0) AS cortesias,
            SUM(bruto) AS monto,
            SUM(neto) AS monto_neto
        FROM lineas
        GROUP BY id_producto
    )
    SELECT COALESCE(json_agg(x ORDER BY x.cantidad DESC, x.monto DESC), '[]'::JSON)
    FROM (
        SELECT
            a.id_producto::INT AS id_producto,
            p.nombre,
            COALESCE(c.nombre, 'Sin categoría') AS categoria,
            a.cantidad::FLOAT8 AS cantidad,
            a.cortesias::FLOAT8 AS cortesias,
            a.monto::FLOAT8 AS monto,
            a.monto_neto::FLOAT8 AS monto_neto,
            pro_costo_unitario_insumo(a.id_producto)::FLOAT8 AS costo_unitario
        FROM agrupado a
        JOIN pro_producto p ON p.id = a.id_producto
        LEFT JOIN pro_subcategoria s ON s.id = p.id_subcategoria
        LEFT JOIN pro_categoria c ON c.id = s.id_categoria
    ) x;
$function$;
