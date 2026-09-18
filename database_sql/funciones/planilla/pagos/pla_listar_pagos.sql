-- Listo los pagos de planilla con filtros por trabajador, período y medio.
--
-- El resumen desglosa por medio de pago porque es lo que el cuadre necesita:
-- solo el efectivo sale del cajón, lo demás sale del banco. Sin ese desglose,
-- el administrador no puede conciliar la caja del día 17.
CREATE OR REPLACE FUNCTION pla_listar_pagos(
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_trabajador BIGINT DEFAULT NULL,
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL,
    p_quincena INTEGER DEFAULT NULL,
    p_medio_pago INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_monto_total NUMERIC(12,2);
    v_efectivo NUMERIC(12,2);
    v_yape NUMERIC(12,2);
    v_tarjeta NUMERIC(12,2);
    v_trabajadores BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Los totales respetan los mismos filtros que el listado: si el usuario
    -- está viendo septiembre, el total debe ser el de septiembre.
    SELECT
        COUNT(*),
        COALESCE(SUM(p.monto), 0),
        COALESCE(SUM(p.monto) FILTER (WHERE p.medio_pago = 1), 0),
        COALESCE(SUM(p.monto) FILTER (WHERE p.medio_pago = 2), 0),
        COALESCE(SUM(p.monto) FILTER (WHERE p.medio_pago = 3), 0),
        COUNT(DISTINCT p.id_trabajador)
    INTO v_total, v_monto_total, v_efectivo, v_yape, v_tarjeta, v_trabajadores
    FROM pla_pago p
    WHERE p.estado = 1
      AND (p_id_trabajador IS NULL OR p.id_trabajador = p_id_trabajador)
      AND (p_anio IS NULL OR p.anio = p_anio)
      AND (p_mes IS NULL OR p.mes = p_mes)
      AND (p_quincena IS NULL OR p.quincena = p_quincena)
      AND (p_medio_pago IS NULL OR p.medio_pago = p_medio_pago)
      AND (p_fecha_desde IS NULL OR p.fecha_pago >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR p.fecha_pago <= p_fecha_hasta);

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.id_trabajador,
            TRIM(t.nombres || ' ' || t.apellidos) AS nombre_trabajador,
            t.puesto,
            p.fecha_pago,
            p.anio,
            p.mes,
            p.quincena,
            p.monto,
            p.medio_pago,
            lo.nombre AS medio_pago_nombre,
            p.id_turno,
            p.observacion,
            p.estado,
            p.fecha_creacion
        FROM pla_pago p
        INNER JOIN pla_trabajador t ON p.id_trabajador = t.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = p.medio_pago
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'MEDIO_PAGO')
        WHERE p.estado = 1
          AND (p_id_trabajador IS NULL OR p.id_trabajador = p_id_trabajador)
          AND (p_anio IS NULL OR p.anio = p_anio)
          AND (p_mes IS NULL OR p.mes = p_mes)
          AND (p_quincena IS NULL OR p.quincena = p_quincena)
          AND (p_medio_pago IS NULL OR p.medio_pago = p_medio_pago)
          AND (p_fecha_desde IS NULL OR p.fecha_pago >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR p.fecha_pago <= p_fecha_hasta)
        ORDER BY p.fecha_pago DESC, t.apellidos ASC
        LIMIT p_limite
        OFFSET p_offset
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'monto_total', v_monto_total,
            'efectivo', v_efectivo,
            'yape', v_yape,
            'tarjeta', v_tarjeta,
            'trabajadores_pagados', v_trabajadores,
            'cantidad_pagos', v_total
        )
    );
END;
$function$;
