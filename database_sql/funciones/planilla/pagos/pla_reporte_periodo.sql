-- Reporte de planilla de un período: total, detalle por trabajador y pendientes.
--
-- Responde las tres preguntas del día de pago en una sola llamada:
--   1. ¿Cuánto se pagó en total y por qué medio?
--   2. ¿A quién se le pagó y cuánto?
--   3. ¿A quién FALTA pagarle?
--
-- La tercera es la que más valor da y la que no sale de un simple listado de
-- pagos: requiere cruzar los trabajadores activos contra los que ya cobraron.
-- Por eso la resuelvo acá y no en el front.
--
-- Si no se indica período, uso el mes actual.
CREATE OR REPLACE FUNCTION pla_reporte_periodo(
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL,
    p_quincena INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio INTEGER;
    v_mes INTEGER;
    v_pagados JSON;
    v_pendientes JSON;
    v_monto_total NUMERIC(12,2);
    v_efectivo NUMERIC(12,2);
    v_yape NUMERIC(12,2);
    v_tarjeta NUMERIC(12,2);
    v_cant_pagados BIGINT;
    v_cant_pendientes BIGINT;
    v_estimado_pendiente NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    v_anio := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_mes  := COALESCE(p_mes,  EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);

    SELECT
        COALESCE(SUM(p.monto), 0),
        COALESCE(SUM(p.monto) FILTER (WHERE p.medio_pago = 1), 0),
        COALESCE(SUM(p.monto) FILTER (WHERE p.medio_pago = 2), 0),
        COALESCE(SUM(p.monto) FILTER (WHERE p.medio_pago = 3), 0),
        COUNT(DISTINCT p.id_trabajador)
    INTO v_monto_total, v_efectivo, v_yape, v_tarjeta, v_cant_pagados
    FROM pla_pago p
    WHERE p.estado = 1
      AND p.anio = v_anio AND p.mes = v_mes
      AND (p_quincena IS NULL OR p.quincena = p_quincena);

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.nombre_trabajador), '[]'::JSON)
    INTO v_pagados
    FROM (
        SELECT
            t.id AS id_trabajador,
            TRIM(t.nombres || ' ' || t.apellidos) AS nombre_trabajador,
            t.puesto,
            t.sueldo_referencial,
            SUM(p.monto) AS monto_pagado,
            COUNT(*) AS cantidad_pagos,
            COALESCE(json_agg(DISTINCT p.quincena ORDER BY p.quincena), '[]'::JSON) AS quincenas
        FROM pla_pago p
        INNER JOIN pla_trabajador t ON p.id_trabajador = t.id
        WHERE p.estado = 1
          AND p.anio = v_anio AND p.mes = v_mes
          AND (p_quincena IS NULL OR p.quincena = p_quincena)
        GROUP BY t.id, t.nombres, t.apellidos, t.puesto, t.sueldo_referencial
    ) x;

    -- Pendientes: solo tiene sentido con una quincena concreta. Sin ella,
    -- "pendiente del mes" es ambiguo (¿le falta una quincena o las dos?),
    -- así que devuelvo lista vacía en ese caso.
    IF p_quincena IS NULL THEN
        v_pendientes := '[]'::JSON;
        v_cant_pendientes := 0;
        v_estimado_pendiente := 0;
    ELSE
        SELECT
            COALESCE(json_agg(row_to_json(y) ORDER BY y.nombre_trabajador), '[]'::JSON),
            COUNT(*),
            COALESCE(SUM(y.sueldo_referencial), 0)
        INTO v_pendientes, v_cant_pendientes, v_estimado_pendiente
        FROM (
            SELECT
                t.id AS id_trabajador,
                TRIM(t.nombres || ' ' || t.apellidos) AS nombre_trabajador,
                t.puesto,
                t.sueldo_referencial
            FROM pla_trabajador t
            WHERE t.estado = 1
              AND NOT EXISTS (
                  SELECT 1 FROM pla_pago p
                  WHERE p.id_trabajador = t.id
                    AND p.estado = 1
                    AND p.anio = v_anio AND p.mes = v_mes AND p.quincena = p_quincena
              )
        ) y;
    END IF;

    RETURN json_build_object(
        'registro', json_build_object(
            'anio', v_anio,
            'mes', v_mes,
            'quincena', p_quincena,
            'monto_total', v_monto_total,
            'efectivo', v_efectivo,
            'yape', v_yape,
            'tarjeta', v_tarjeta,
            'cantidad_pagados', v_cant_pagados,
            'cantidad_pendientes', v_cant_pendientes,
            -- Estimado según el sueldo referencial. Es una proyección para
            -- saber cuánto falta desembolsar, no un monto exigible.
            'estimado_pendiente', v_estimado_pendiente,
            'pagados', v_pagados,
            'pendientes', v_pendientes
        )
    );
END;
$function$;
