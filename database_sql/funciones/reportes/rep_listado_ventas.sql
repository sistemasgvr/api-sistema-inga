-- Listado de ventas del período, de la más reciente a la más antigua.
DROP FUNCTION IF EXISTS rep_listado_ventas(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_listado_ventas(
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
    SELECT COALESCE(json_agg(x ORDER BY x.fecha DESC, x.id DESC), '[]'::JSON)
    FROM (
        SELECT
            v.id::INT AS id,
            v.codigo,
            to_char(v.fecha_lima, 'YYYY-MM-DD HH24:MI') AS fecha,
            v.tipo_pedido::INT AS tipo_pedido,
            (SELECT m.codigo FROM ven_mesa m WHERE m.id = v.id_mesa) AS mesa,
            (
                SELECT COALESCE(NULLIF(TRIM(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username)
                FROM auth_usuario_datos u
                WHERE u.id = v.id_mozo
            ) AS mozo,
            v.num_comensales::INT AS comensales,
            v.monto_total::FLOAT8 AS total,
            COALESCE((
                SELECT string_agg(COALESCE(md.nombre, g.medio_pago::TEXT), ', ' ORDER BY g.id)
                FROM ven_pago g
                LEFT JOIN medios md ON md.medio_pago = g.medio_pago
                WHERE g.id_pedido = v.id AND g.estado = 1
            ), '') AS medios
        FROM ventas v
    ) x;
$function$;
