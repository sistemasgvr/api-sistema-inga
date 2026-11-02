-- Gastos diarios por ítem comprado.
DROP FUNCTION IF EXISTS rep_gastos_diarios_por_item(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_gastos_diarios_por_item(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT COALESCE(json_agg(x ORDER BY x.total DESC), '[]'::JSON)
    FROM (
        SELECT
            COALESCE(i.nombre, p.nombre, 'Sin nombre') AS item,
            COALESCE(gc.nombre, 'Compra a inventario') AS categoria,
            COUNT(*)::INT AS compras,
            SUM(d.subtotal)::FLOAT8 AS total,
            COALESCE(SUM(d.subtotal) FILTER (WHERE d.forma_pago = 3), 0)::FLOAT8 AS credito
        FROM gdo_gasto_detalle d
        JOIN gdo_gasto_dia g ON g.id = d.id_gasto_dia
        LEFT JOIN gdo_insumo i ON i.id = d.id_insumo
        LEFT JOIN gdo_categoria gc ON gc.id = i.id_categoria
        LEFT JOIN pro_producto p ON p.id = d.id_producto
        WHERE d.estado = 1
          AND g.estado = 1
          AND g.fecha_gasto BETWEEN p_fecha_desde AND p_fecha_hasta
          AND rep_sucursal_en_ambito(g.id_sucursal, p_id_empresa, p_id_sucursal)
        GROUP BY 1, 2
    ) x;
$function$;
