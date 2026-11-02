-- Ventas por medio de pago (pagos vigentes).
DROP FUNCTION IF EXISTS rep_ventas_por_medio(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_ventas_por_medio(
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
    medios AS (
        SELECT o.valor_entero AS medio_pago, o.nombre
        FROM gen_lista_opcion o
        JOIN gen_lista l ON l.id = o.id_lista
        WHERE l.codigo = 'MEDIO_PAGO'
    )
    SELECT COALESCE(json_agg(x ORDER BY x.medio_pago), '[]'::JSON)
    FROM (
        SELECT
            g.medio_pago::INT AS medio_pago,
            COALESCE(m.nombre, g.medio_pago::TEXT) AS nombre,
            COUNT(*)::INT AS cantidad,
            SUM(g.monto)::FLOAT8 AS total
        FROM ven_pago g
        JOIN ventas v ON v.id = g.id_pedido
        LEFT JOIN medios m ON m.medio_pago = g.medio_pago
        WHERE g.estado = 1
        GROUP BY g.medio_pago, m.nombre
    ) x;
$function$;
