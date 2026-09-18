-- Listo el personal que cobra planilla.
--
-- Devuelvo "pagado_periodo" y "ultimo_pago" porque la pantalla necesita
-- responder de un vistazo la pregunta del día de pago: "¿a quién ya le pagué
-- esta quincena y a quién no?". Si no los mandara desde acá, el front tendría
-- que hacer una consulta por cada fila.
--
-- Los parámetros de período son opcionales: cuando no se mandan uso el mes y
-- año actuales, que es el caso normal al abrir la pantalla.
CREATE OR REPLACE FUNCTION pla_listar_trabajadores(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL,
    p_quincena INTEGER DEFAULT NULL,
    p_estado INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_cant_total BIGINT;
    v_cant_activos BIGINT;
    v_cant_inactivos BIGINT;
    v_anio INTEGER;
    v_mes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_anio := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_mes  := COALESCE(p_mes,  EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE t.estado = 1),
        COUNT(*) FILTER (WHERE t.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM pla_trabajador t;

    SELECT COUNT(*) INTO v_total
    FROM pla_trabajador t
    WHERE (p_estado IS NULL OR t.estado = p_estado)
      AND (
          p_busqueda = ''
          OR COALESCE(t.num_documento, '') LIKE '%' || p_busqueda || '%'
          OR LOWER(t.nombres || ' ' || t.apellidos) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(t.puesto, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            t.id,
            t.id_sucursal,
            s.nombre AS nombre_sucursal,
            t.nombres,
            t.apellidos,
            TRIM(t.nombres || ' ' || t.apellidos) AS nombre_completo,
            t.num_documento,
            t.puesto,
            t.sueldo_referencial,
            t.estado,
            -- Cuánto se le pagó ya en el período consultado.
            COALESCE(pg.pagado_periodo, 0) AS pagado_periodo,
            COALESCE(pg.pagos_periodo, 0) AS pagos_periodo,
            -- Si se filtró por quincena concreta, esto dice si ya cobró esa.
            pg.quincenas_pagadas,
            up.fecha_pago AS ultimo_pago_fecha,
            up.monto AS ultimo_pago_monto,
            t.fecha_creacion,
            t.fecha_modificacion
        FROM pla_trabajador t
        LEFT JOIN gen_sucursal s ON t.id_sucursal = s.id
        LEFT JOIN LATERAL (
            SELECT
                SUM(p.monto) AS pagado_periodo,
                COUNT(*) AS pagos_periodo,
                -- Array con las quincenas ya pagadas del período: la pantalla
                -- lo usa para marcar "1ra ✓ / 2da pendiente" sin más consultas.
                COALESCE(json_agg(DISTINCT p.quincena ORDER BY p.quincena), '[]'::JSON) AS quincenas_pagadas
            FROM pla_pago p
            WHERE p.id_trabajador = t.id
              AND p.estado = 1
              AND p.anio = v_anio
              AND p.mes = v_mes
              AND (p_quincena IS NULL OR p.quincena = p_quincena)
        ) pg ON TRUE
        LEFT JOIN LATERAL (
            SELECT p2.fecha_pago, p2.monto
            FROM pla_pago p2
            WHERE p2.id_trabajador = t.id AND p2.estado = 1
            ORDER BY p2.fecha_pago DESC, p2.id DESC
            LIMIT 1
        ) up ON TRUE
        WHERE (p_estado IS NULL OR t.estado = p_estado)
          AND (
              p_busqueda = ''
              OR COALESCE(t.num_documento, '') LIKE '%' || p_busqueda || '%'
              OR LOWER(t.nombres || ' ' || t.apellidos) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(t.puesto, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY t.apellidos ASC, t.nombres ASC
        LIMIT p_limite
        OFFSET p_offset
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total', v_cant_total,
            'activos', v_cant_activos,
            'inactivos', v_cant_inactivos,
            'anio', v_anio,
            'mes', v_mes
        )
    );
END;
$function$;
