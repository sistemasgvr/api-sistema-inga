-- Ingresos y egresos de caja del período.
DROP FUNCTION IF EXISTS rep_movimientos_caja(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_movimientos_caja(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT COALESCE(json_agg(x ORDER BY x.fecha DESC, x.id DESC), '[]'::JSON)
    FROM (
        SELECT
            m.id::INT AS id,
            to_char(m.fecha_creacion AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI') AS fecha,
            cj.nombre AS caja,
            m.tipo_movimiento::INT AS tipo_movimiento,
            m.monto::FLOAT8 AS monto,
            m.motivo,
            COALESCE(NULLIF(TRIM(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username) AS usuario
        FROM caj_movimiento m
        JOIN caj_turno t ON t.id = m.id_turno
        JOIN caj_caja cj ON cj.id = t.id_caja
        LEFT JOIN auth_usuario_datos u ON u.id = m.id_usuario_creacion
        WHERE m.estado = 1
          AND (m.fecha_creacion AT TIME ZONE 'America/Lima')::DATE BETWEEN p_fecha_desde AND p_fecha_hasta
          AND rep_sucursal_en_ambito(cj.id_sucursal, p_id_empresa, p_id_sucursal)
    ) x;
$function$;
