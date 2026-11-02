-- Ventas por tipo de pedido.
DROP FUNCTION IF EXISTS rep_ventas_por_tipo(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_ventas_por_tipo(
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
    )
    SELECT COALESCE(json_agg(x ORDER BY x.tipo_pedido), '[]'::JSON)
    FROM (
        SELECT
            tipo_pedido::INT AS tipo_pedido,
            COUNT(*)::INT AS cantidad,
            SUM(monto_total)::FLOAT8 AS total,
            COALESCE(SUM(num_comensales), 0)::INT AS comensales
        FROM ventas
        GROUP BY 1
    ) x;
$function$;
