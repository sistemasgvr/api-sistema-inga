-- Saldo actual de CxC más lo movido en el período. Entran las personas con deuda o
-- con algún movimiento en el rango. Las cuentas son de la empresa: la sucursal no filtra.
DROP FUNCTION IF EXISTS rep_cuentas_por_cobrar(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_cuentas_por_cobrar(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    WITH periodo AS (
        SELECT
            id_persona,
            COALESCE(SUM(monto) FILTER (WHERE tipo_movimiento = 1), 0) AS cargos,
            COALESCE(SUM(monto) FILTER (WHERE tipo_movimiento = 2), 0) AS abonos,
            COALESCE(SUM(monto) FILTER (WHERE tipo_movimiento = 3), 0) AS ajustes
        FROM cxc_movimiento
        WHERE estado = 1
          AND (fecha_creacion AT TIME ZONE 'America/Lima')::DATE BETWEEN p_fecha_desde AND p_fecha_hasta
          AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa)
        GROUP BY id_persona
    )
    SELECT COALESCE(json_agg(x ORDER BY x.saldo DESC NULLS LAST, x.nombre), '[]'::JSON)
    FROM (
        SELECT
            s.id_persona::INT AS id_persona,
            s.nombre,
            s.num_documento,
            s.convenio,
            COALESCE(s.saldo, 0)::FLOAT8 AS saldo,
            COALESCE(p.cargos, 0)::FLOAT8 AS cargos_periodo,
            COALESCE(p.abonos, 0)::FLOAT8 AS abonos_periodo,
            COALESCE(p.ajustes, 0)::FLOAT8 AS ajustes_periodo
        FROM vw_cxc_saldo_persona s
        LEFT JOIN periodo p ON p.id_persona = s.id_persona
        WHERE (p_id_empresa IS NULL OR s.id_empresa = p_id_empresa)
          AND (COALESCE(s.saldo, 0) <> 0 OR p.id_persona IS NOT NULL)
    ) x;
$function$;
