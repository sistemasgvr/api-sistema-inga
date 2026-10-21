-- Reporte mensual de gastos administrativos: totales por tipo y medio de pago, desglose por
-- categoría raíz y comparación con el mes anterior.
DROP FUNCTION IF EXISTS gad_reporte_mensual(
    p_anio INTEGER,
    p_mes INTEGER
);
CREATE OR REPLACE FUNCTION gad_reporte_mensual(
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio INTEGER;
    v_mes INTEGER;
    v_anio_prev INTEGER;
    v_mes_prev INTEGER;
    v_total NUMERIC(12,2);
    v_fijos NUMERIC(12,2);
    v_variables NUMERIC(12,2);
    v_efectivo NUMERIC(12,2);
    v_yape NUMERIC(12,2);
    v_tarjeta NUMERIC(12,2);
    v_cantidad BIGINT;
    v_total_prev NUMERIC(12,2);
    v_por_categoria JSON;
    v_prev DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_anio := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_mes  := COALESCE(p_mes,  EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);

    v_prev := (make_date(v_anio, v_mes, 1) - INTERVAL '1 month')::DATE;
    v_anio_prev := EXTRACT(YEAR FROM v_prev)::INTEGER;
    v_mes_prev := EXTRACT(MONTH FROM v_prev)::INTEGER;

    SELECT
        COALESCE(SUM(g.monto), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE c.tipo_gasto = 1), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE c.tipo_gasto = 2), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE g.medio_pago = 1), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE g.medio_pago = 2), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE g.medio_pago = 3), 0),
        COUNT(*)
    INTO v_total, v_fijos, v_variables, v_efectivo, v_yape, v_tarjeta, v_cantidad
    FROM gad_gasto g
    INNER JOIN gad_categoria c ON g.id_categoria = c.id
    WHERE g.estado = 1 AND g.anio = v_anio AND g.mes = v_mes;

    SELECT COALESCE(SUM(g.monto), 0)
    INTO v_total_prev
    FROM gad_gasto g
    WHERE g.estado = 1 AND g.anio = v_anio_prev AND g.mes = v_mes_prev;

    -- COALESCE(padre, propia) agrupa cada subcategoría bajo su rama.
    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.monto DESC), '[]'::JSON)
    INTO v_por_categoria
    FROM (
        SELECT
            raiz.id AS id_categoria,
            raiz.nombre AS nombre_categoria,
            raiz.tipo_gasto,
            CASE raiz.tipo_gasto WHEN 1 THEN 'Fijo' ELSE 'Variable' END AS tipo_gasto_nombre,
            SUM(g.monto) AS monto,
            COUNT(*) AS cantidad,
            COALESCE(json_agg(
                json_build_object('nombre', c.nombre, 'monto', g.monto, 'concepto', g.concepto)
                ORDER BY g.monto DESC
            ) FILTER (WHERE c.id <> raiz.id), '[]'::JSON) AS detalle
        FROM gad_gasto g
        INNER JOIN gad_categoria c ON g.id_categoria = c.id
        INNER JOIN gad_categoria raiz
            ON raiz.id = COALESCE(c.id_categoria_padre, c.id)
        WHERE g.estado = 1 AND g.anio = v_anio AND g.mes = v_mes
        GROUP BY raiz.id, raiz.nombre, raiz.tipo_gasto
    ) x;

    RETURN json_build_object(
        'registro', json_build_object(
            'anio', v_anio,
            'mes', v_mes,
            'monto_total', v_total,
            'fijos', v_fijos,
            'variables', v_variables,
            'efectivo', v_efectivo,
            'yape', v_yape,
            'tarjeta', v_tarjeta,
            'cantidad', v_cantidad,
            'total_mes_anterior', v_total_prev,
            -- NULL si el mes anterior no tuvo gastos: un 0% sería engañoso.
            'variacion_porcentual',
                CASE WHEN v_total_prev > 0
                     THEN ROUND(((v_total - v_total_prev) / v_total_prev) * 100, 2)
                     ELSE NULL
                END,
            'por_categoria', v_por_categoria
        )
    );
END;
$function$;
