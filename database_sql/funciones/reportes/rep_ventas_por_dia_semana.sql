-- Ventas por día de la semana (1 = lunes).
DROP FUNCTION IF EXISTS rep_ventas_por_dia_semana(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_ventas_por_dia_semana(
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
    SELECT COALESCE(json_agg(x ORDER BY x.dia), '[]'::JSON)
    FROM (
        SELECT
            EXTRACT(ISODOW FROM fecha_lima)::INT AS dia,
            COUNT(*)::INT AS cantidad,
            SUM(monto_total)::FLOAT8 AS total
        FROM ventas
        GROUP BY 1
    ) x;
$function$;
