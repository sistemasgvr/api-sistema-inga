-- Listo el historial de movimientos (cargos y abonos) con filtros.
--
-- Es el "estado de cuenta" de un proveedor: qué se compró a crédito, qué se
-- le pagó y cómo quedó el saldo después de cada movimiento.
--
-- Ordeno por fecha DESCENDENTE porque lo que se consulta es lo reciente. El
-- saldo_resultante de cada fila ya viene guardado desde el momento en que se
-- registró, así que la columna "saldo" del historial es la foto real de
-- entonces, no un recálculo de hoy.
CREATE OR REPLACE FUNCTION cxp_listar_movimientos(
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_persona BIGINT DEFAULT NULL,
    p_tipo_movimiento INT DEFAULT NULL,
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL,
    p_semana INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_cargos NUMERIC(12,2);
    v_abonos NUMERIC(12,2);
    v_efectivo NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2 AND m.medio_pago = 1), 0)
    INTO v_total, v_cargos, v_abonos, v_efectivo
    FROM cxp_movimiento m
    WHERE m.estado = 1
      AND (p_id_persona IS NULL OR m.id_persona = p_id_persona)
      AND (p_tipo_movimiento IS NULL OR m.tipo_movimiento = p_tipo_movimiento)
      AND (p_anio IS NULL OR m.anio = p_anio)
      AND (p_mes IS NULL OR m.mes = p_mes)
      AND (p_semana IS NULL OR m.semana = p_semana)
      AND (p_fecha_desde IS NULL OR m.fecha_movimiento >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha_movimiento <= p_fecha_hasta);

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.id_persona,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) AS nombre_proveedor,
            m.tipo_movimiento,
            CASE m.tipo_movimiento
                WHEN 1 THEN 'Cargo'
                WHEN 2 THEN 'Abono'
                ELSE 'Ajuste'
            END AS tipo_movimiento_nombre,
            m.monto,
            m.saldo_resultante,
            m.medio_pago,
            lo.nombre AS medio_pago_nombre,
            m.fecha_movimiento,
            m.anio,
            m.mes,
            m.semana,
            m.num_comprobante,
            m.id_gasto_diario,
            m.id_turno,
            m.observacion,
            m.estado,
            m.fecha_creacion
        FROM cxp_movimiento m
        INNER JOIN cli_persona p ON m.id_persona = p.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = m.medio_pago
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'MEDIO_PAGO')
        WHERE m.estado = 1
          AND (p_id_persona IS NULL OR m.id_persona = p_id_persona)
          AND (p_tipo_movimiento IS NULL OR m.tipo_movimiento = p_tipo_movimiento)
          AND (p_anio IS NULL OR m.anio = p_anio)
          AND (p_mes IS NULL OR m.mes = p_mes)
          AND (p_semana IS NULL OR m.semana = p_semana)
          AND (p_fecha_desde IS NULL OR m.fecha_movimiento >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha_movimiento <= p_fecha_hasta)
        ORDER BY m.fecha_movimiento DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total_cargos', v_cargos,
            'total_abonos', v_abonos,
            'abonos_efectivo', v_efectivo,
            'neto', v_cargos - v_abonos,
            'cantidad', v_total
        )
    );
END;
$function$;
