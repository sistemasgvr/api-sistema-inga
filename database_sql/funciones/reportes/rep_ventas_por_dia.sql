-- Ventas por día de Lima.
DROP FUNCTION IF EXISTS rep_ventas_por_dia(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_ventas_por_dia(
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
    SELECT COALESCE(json_agg(x ORDER BY x.fecha), '[]'::JSON)
    FROM (
        SELECT
            to_char(fecha_lima, 'YYYY-MM-DD') AS fecha,
            COUNT(*)::INT AS cantidad,
            SUM(monto_total)::FLOAT8 AS total,
            SUM(monto_total - monto_igv)::FLOAT8 AS neto
        FROM ventas
        GROUP BY 1
    ) x;
$function$;
