-- Turnos de caja abiertos en el período, con sus totales.
DROP FUNCTION IF EXISTS rep_turnos(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_turnos(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT COALESCE(json_agg(x ORDER BY x.fecha_apertura DESC, x.id DESC), '[]'::JSON)
    FROM (
        SELECT
            t.id::INT AS id,
            cj.nombre AS caja,
            COALESCE(NULLIF(TRIM(concat_ws(' ', u.nombres, u.apellidos)), ''), u.username) AS cajero,
            to_char(t.fecha_apertura AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI') AS fecha_apertura,
            to_char(t.fecha_cierre AT TIME ZONE 'America/Lima', 'YYYY-MM-DD HH24:MI') AS fecha_cierre,
            t.estado_turno::INT AS estado_turno,
            t.monto_apertura::FLOAT8 AS monto_apertura,
            t.monto_cierre_declarado::FLOAT8 AS monto_declarado,
            t.monto_diferencia::FLOAT8 AS monto_diferencia,
            caj_calcular_totales_turno(t.id) AS totales
        FROM caj_turno t
        JOIN caj_caja cj ON cj.id = t.id_caja
        LEFT JOIN auth_usuario_datos u ON u.id = t.id_cajero
        WHERE t.estado = 1
          AND (t.fecha_apertura AT TIME ZONE 'America/Lima')::DATE BETWEEN p_fecha_desde AND p_fecha_hasta
          AND rep_sucursal_en_ambito(cj.id_sucursal, p_id_empresa, p_id_sucursal)
    ) x;
$function$;
