-- Reporte consolidado de una quincena, agrupado por empresa y con el detalle de
-- cada trabajador.
--
-- Este es EL entregable del módulo. El alcance lo dice claro: a inicios de cada
-- mes hay que mandarle a cada empresa del consorcio el consolidado de lo que
-- consumió su gente, y la empresa paga contra eso y luego se lo descuenta al
-- trabajador de su planilla.
--
-- Lo devuelvo agrupado (empresa → trabajadores) en vez de una lista plana
-- porque así es como se imprime: una hoja por empresa, con el total abajo. Si
-- devolviera filas sueltas, el front tendría que reagrupar, y ese es
-- exactamente el trabajo que la base hace mejor.
--
-- Si no se pasa periodo, uso la quincena en curso, que es lo que se quiere el
-- 95% de las veces.
CREATE OR REPLACE FUNCTION cxc_reporte_periodo(
    p_anio SMALLINT DEFAULT NULL,
    p_mes SMALLINT DEFAULT NULL,
    p_quincena SMALLINT DEFAULT NULL,
    p_id_convenio BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio SMALLINT;
    v_mes SMALLINT;
    v_quincena SMALLINT;
    v_empresas JSON;
    v_total_cargos NUMERIC(12,2);
    v_total_abonos NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    v_anio := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::SMALLINT);
    v_mes := COALESCE(p_mes, EXTRACT(MONTH FROM CURRENT_DATE)::SMALLINT);
    v_quincena := COALESCE(
        p_quincena,
        CASE WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 15 THEN 1 ELSE 2 END
    );

    SELECT
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0)
    INTO v_total_cargos, v_total_abonos
    FROM cxc_movimiento m
    WHERE m.estado = 1
      AND m.anio = v_anio AND m.mes = v_mes AND m.quincena = v_quincena
      AND (p_id_convenio IS NULL OR m.id_convenio = p_id_convenio);

    SELECT COALESCE(json_agg(row_to_json(e) ORDER BY e.total_consumo DESC), '[]'::JSON)
    INTO v_empresas
    FROM (
        SELECT
            t.id_convenio,
            t.nombre_convenio,
            SUM(t.consumo) AS total_consumo,
            SUM(t.abono) AS total_abono,
            SUM(t.consumo) - SUM(t.abono) AS total_neto,
            COUNT(*) AS cantidad_personas,
            json_agg(
                json_build_object(
                    'id_persona', t.id_persona,
                    'nombre_persona', t.nombre_persona,
                    'num_documento', t.num_documento,
                    'consumo', t.consumo,
                    'abono', t.abono,
                    'neto', t.consumo - t.abono,
                    'cantidad_movimientos', t.cantidad_movimientos
                ) ORDER BY t.consumo DESC
            ) AS personas
        FROM (
            SELECT
                m.id_convenio,
                COALESCE(c.nombre, 'Sin convenio') AS nombre_convenio,
                m.id_persona,
                COALESCE(
                    NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                    p.razon_social
                ) AS nombre_persona,
                p.num_documento,
                COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0) AS consumo,
                COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0) AS abono,
                COUNT(*) AS cantidad_movimientos
            FROM cxc_movimiento m
            INNER JOIN cli_persona p ON m.id_persona = p.id
            LEFT JOIN cli_convenio c ON m.id_convenio = c.id
            WHERE m.estado = 1
              AND m.anio = v_anio AND m.mes = v_mes AND m.quincena = v_quincena
              AND (p_id_convenio IS NULL OR m.id_convenio = p_id_convenio)
            GROUP BY m.id_convenio, c.nombre, m.id_persona,
                     p.nombres, p.apellido_paterno, p.razon_social, p.num_documento
        ) t
        GROUP BY t.id_convenio, t.nombre_convenio
    ) e;

    RETURN json_build_object(
        'registro', json_build_object(
            'periodo', json_build_object(
                'anio', v_anio,
                'mes', v_mes,
                'quincena', v_quincena,
                'etiqueta', 'Quincena ' || v_quincena || ' — ' ||
                            TO_CHAR(MAKE_DATE(v_anio, v_mes, 1), 'TMMonth YYYY')
            ),
            'total_cargos', v_total_cargos,
            'total_abonos', v_total_abonos,
            'total_neto', v_total_cargos - v_total_abonos,
            'empresas', v_empresas
        )
    );
END;
$function$;
