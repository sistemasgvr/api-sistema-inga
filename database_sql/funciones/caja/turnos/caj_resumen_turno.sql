-- Resumen completo de un turno: totales, movimientos y arqueo en una sola llamada.
--
-- Es lo que pide el requerimiento de M11: "total por medio de pago, movimientos
-- y diferencia de arqueo". Lo devuelvo todo junto porque la pantalla de cierre
-- los muestra en la misma vista y no tiene sentido hacer tres viajes.
--
-- También sirve como comprobante del turno: es la información que el
-- administrador revisa cuando un cierre no cuadra.
CREATE OR REPLACE FUNCTION caj_resumen_turno(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_turno JSON;
    v_movimientos JSON;
    v_arqueo JSON;
    v_total_arqueo NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    -- caj_obtener_turno ya trae la fila del turno con todos los totales.
    v_turno := (caj_obtener_turno(p_id)::JSONB->'registro')::JSON;

    IF v_turno IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    -- Movimientos manuales de caja + lo que cobraron o pagaron otros módulos
    -- contra este turno (proveedores, gastos, planilla, compras, cobranzas).
    -- `clave` es única entre orígenes: los id se repiten de una tabla a otra.
    -- Los externos se anulan en su propio módulo, no desde la caja.
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha_creacion), '[]'::JSON)
    INTO v_movimientos
    FROM (
        SELECT
            'CAJA-' || m.id AS clave,
            'CAJA' AS origen,
            'Caja' AS origen_nombre,
            m.id,
            m.tipo_movimiento,
            lo.nombre AS tipo_movimiento_nombre,
            1 AS medio_pago,
            'Efectivo' AS medio_pago_nombre,
            m.monto,
            m.motivo,
            m.id_usuario_autoriza,
            TRIM(COALESCE(ua.nombres, '') || ' ' || COALESCE(ua.apellidos, '')) AS nombre_autoriza,
            m.fecha_creacion
        FROM caj_movimiento m
        LEFT JOIN auth_usuario_datos ua ON m.id_usuario_autoriza = ua.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = m.tipo_movimiento
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'CAJA_MOV_TIPO')
        WHERE m.id_turno = p_id AND m.estado = 1

        UNION ALL

        SELECT
            x.origen || '-' || x.id,
            x.origen,
            x.origen_nombre,
            x.id,
            x.tipo_movimiento,
            CASE x.tipo_movimiento WHEN 1 THEN 'Ingreso' ELSE 'Egreso' END,
            x.medio_pago,
            CASE x.medio_pago
                WHEN 1 THEN 'Efectivo'
                WHEN 2 THEN 'Yape'
                ELSE 'Tarjeta / transferencia'
            END,
            x.monto,
            x.motivo,
            NULL,
            NULL,
            x.fecha_creacion
        FROM caj_movimientos_externos(p_id) x
    ) t;

    SELECT
        COALESCE(json_agg(row_to_json(t) ORDER BY t.denominacion DESC), '[]'::JSON),
        COALESCE(SUM(t.monto_subtotal), 0)
    INTO v_arqueo, v_total_arqueo
    FROM (
        SELECT
            a.id,
            a.denominacion,
            a.cantidad,
            a.monto_subtotal
        FROM caj_arqueo_detalle a
        WHERE a.id_turno = p_id AND a.estado = 1 AND a.cantidad > 0
    ) t;

    RETURN json_build_object(
        'registro', json_build_object(
            'turno', v_turno,
            'movimientos', v_movimientos,
            'arqueo', v_arqueo,
            -- Suma de billetes y monedas contados. La pantalla la compara con
            -- el efectivo esperado para mostrar la diferencia antes de cerrar.
            'total_arqueo', v_total_arqueo
        )
    );
END;
$function$;
