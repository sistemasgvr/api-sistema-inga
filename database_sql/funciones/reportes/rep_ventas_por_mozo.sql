-- Ventas por mozo. Mesas atendidas = pedidos de mesa cobrados (cada apertura de mesa
-- es una atención, aunque se repita la misma mesa en el día).
DROP FUNCTION IF EXISTS rep_ventas_por_mozo(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_ventas_por_mozo(
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
    SELECT COALESCE(json_agg(x ORDER BY x.total DESC), '[]'::JSON)
    FROM (
        SELECT
            v.id_mozo::INT AS id_mozo,
            COALESCE(NULLIF(TRIM(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username, 'Sin nombre') AS nombre,
            COUNT(*)::INT AS cantidad,
            SUM(v.monto_total)::FLOAT8 AS total,
            COUNT(*) FILTER (WHERE v.id_mesa IS NOT NULL)::INT AS mesas,
            COALESCE(SUM(v.num_comensales), 0)::INT AS comensales
        FROM ventas v
        LEFT JOIN auth_usuario_datos u ON u.id = v.id_mozo
        GROUP BY v.id_mozo, u.nombres, u.apellidos, u.username
    ) x;
$function$;
