-- Reporte de CxP por período (por defecto el mes actual), agrupado por proveedor y semana.
DROP FUNCTION IF EXISTS cxp_reporte_periodo(
    p_anio INTEGER,
    p_mes INTEGER
);
CREATE OR REPLACE FUNCTION cxp_reporte_periodo(
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio INTEGER;
    v_mes INTEGER;
    v_cargos NUMERIC(12,2);
    v_abonos NUMERIC(12,2);
    v_deuda_actual NUMERIC(12,2);
    v_por_proveedor JSON;
    v_por_semana JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_anio := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_mes  := COALESCE(p_mes,  EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);

    SELECT
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0)
    INTO v_cargos, v_abonos
    FROM cxp_movimiento m
    WHERE m.estado = 1 AND m.anio = v_anio AND m.mes = v_mes;

    -- La deuda actual NO se filtra por período: es el saldo vivo acumulado.
    SELECT COALESCE(SUM(v.saldo) FILTER (WHERE v.saldo > 0), 0)
    INTO v_deuda_actual
    FROM vw_cxp_saldo_proveedor v;

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.saldo_actual DESC), '[]'::JSON)
    INTO v_por_proveedor
    FROM (
        SELECT
            p.id AS id_persona,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) AS nombre_proveedor,
            COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0) AS cargos_periodo,
            COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0) AS abonos_periodo,
            cxp_calcular_saldo_proveedor(p.id) AS saldo_actual
        FROM cli_persona p
        INNER JOIN cxp_movimiento m
            ON m.id_persona = p.id AND m.estado = 1
           AND m.anio = v_anio AND m.mes = v_mes
        WHERE p.es_proveedor = TRUE
        GROUP BY p.id, p.nombres, p.apellido_paterno, p.razon_social
    ) x;

    SELECT COALESCE(json_agg(row_to_json(y) ORDER BY y.semana), '[]'::JSON)
    INTO v_por_semana
    FROM (
        SELECT
            m.semana,
            MIN(m.fecha_movimiento) AS desde,
            MAX(m.fecha_movimiento) AS hasta,
            COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0) AS cargos,
            COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0) AS abonos
        FROM cxp_movimiento m
        WHERE m.estado = 1 AND m.anio = v_anio AND m.mes = v_mes
        GROUP BY m.semana
    ) y;

    RETURN json_build_object(
        'registro', json_build_object(
            'anio', v_anio,
            'mes', v_mes,
            'cargos_periodo', v_cargos,
            'abonos_periodo', v_abonos,
            'neto_periodo', v_cargos - v_abonos,
            'deuda_actual_total', v_deuda_actual,
            'por_proveedor', v_por_proveedor,
            'por_semana', v_por_semana
        )
    );
END;
$function$;
