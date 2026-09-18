-- Listo el historial de días con gasto, con filtros por período.
--
-- Muestro los totales que ya están guardados en la cabecera, sin re-sumar el
-- detalle: para eso los mantengo denormalizados.
--
-- El resumen acumula el período completo, que es lo que el administrador mira
-- al cerrar el mes: cuánto se fue en efectivo, cuánto en Yape y cuánto quedó
-- a crédito.
CREATE OR REPLACE FUNCTION gdo_listar_dias(
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_efectivo NUMERIC(12,2);
    v_yape NUMERIC(12,2);
    v_credito NUMERIC(12,2);
    v_general NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        COALESCE(SUM(d.total_efectivo), 0),
        COALESCE(SUM(d.total_yape), 0),
        COALESCE(SUM(d.total_credito), 0),
        COALESCE(SUM(d.total_general), 0)
    INTO v_total, v_efectivo, v_yape, v_credito, v_general
    FROM gdo_gasto_dia d
    WHERE d.estado = 1
      AND (p_anio IS NULL OR d.anio = p_anio)
      AND (p_mes IS NULL OR d.mes = p_mes)
      AND (p_fecha_desde IS NULL OR d.fecha_gasto >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR d.fecha_gasto <= p_fecha_hasta);

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            d.id,
            d.fecha_gasto,
            d.anio,
            d.mes,
            d.id_sucursal,
            s.nombre AS nombre_sucursal,
            d.id_turno,
            d.total_efectivo,
            d.total_yape,
            d.total_credito,
            d.total_general,
            (
                SELECT COUNT(*)
                FROM gdo_gasto_detalle det
                WHERE det.id_gasto_dia = d.id AND det.estado = 1
            ) AS cantidad_items,
            d.observacion,
            d.estado
        FROM gdo_gasto_dia d
        LEFT JOIN gen_sucursal s ON d.id_sucursal = s.id
        WHERE d.estado = 1
          AND (p_anio IS NULL OR d.anio = p_anio)
          AND (p_mes IS NULL OR d.mes = p_mes)
          AND (p_fecha_desde IS NULL OR d.fecha_gasto >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR d.fecha_gasto <= p_fecha_hasta)
        ORDER BY d.fecha_gasto DESC
        LIMIT p_limite
        OFFSET p_offset
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total_efectivo', v_efectivo,
            'total_yape', v_yape,
            'total_credito', v_credito,
            'total_general', v_general,
            'dias', v_total
        )
    );
END;
$function$;
