-- Gastos diarios por día.
DROP FUNCTION IF EXISTS rep_gastos_diarios_por_dia(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_gastos_diarios_por_dia(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT COALESCE(json_agg(x ORDER BY x.fecha), '[]'::JSON)
    FROM (
        SELECT
            to_char(g.fecha_gasto, 'YYYY-MM-DD') AS fecha,
            SUM(g.total_efectivo)::FLOAT8 AS efectivo,
            SUM(g.total_yape)::FLOAT8 AS yape,
            SUM(g.total_credito)::FLOAT8 AS credito,
            SUM(g.total_general)::FLOAT8 AS total
        FROM gdo_gasto_dia g
        WHERE g.estado = 1
          AND g.fecha_gasto BETWEEN p_fecha_desde AND p_fecha_hasta
          AND rep_sucursal_en_ambito(g.id_sucursal, p_id_empresa, p_id_sucursal)
        GROUP BY g.fecha_gasto
    ) x;
$function$;
