-- Estado de cuenta de un proveedor: su saldo, sus totales y sus últimos movimientos.
--
-- Lo devuelvo todo junto porque la pantalla de detalle los muestra en la misma
-- vista y no tiene sentido hacer tres viajes.
--
-- También sirve como el documento que se le enseña al proveedor cuando hay
-- discrepancia sobre cuánto se le debe.
CREATE OR REPLACE FUNCTION cxp_obtener_estado_cuenta(
    p_id_persona BIGINT,
    p_limite_movimientos INTEGER DEFAULT 20
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_proveedor JSON;
    v_movimientos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(x) INTO v_proveedor
    FROM (
        SELECT
            v.id_persona,
            v.nombre,
            v.num_documento,
            v.saldo,
            v.total_cargos,
            v.total_abonos,
            v.ultimo_abono,
            CASE
                WHEN v.ultimo_abono IS NULL THEN NULL
                ELSE (CURRENT_DATE - v.ultimo_abono)
            END AS dias_sin_abonar,
            p.telefono,
            p.email
        FROM vw_cxp_saldo_proveedor v
        INNER JOIN cli_persona p ON p.id = v.id_persona
        WHERE v.id_persona = p_id_persona
    ) x;

    IF v_proveedor IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(y) ORDER BY y.fecha_movimiento DESC, y.id DESC), '[]'::JSON)
    INTO v_movimientos
    FROM (
        SELECT
            m.id,
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
            m.semana,
            m.num_comprobante,
            m.observacion
        FROM cxp_movimiento m
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = m.medio_pago
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'MEDIO_PAGO')
        WHERE m.id_persona = p_id_persona AND m.estado = 1
        ORDER BY m.fecha_movimiento DESC, m.id DESC
        LIMIT COALESCE(p_limite_movimientos, 20)
    ) y;

    RETURN json_build_object(
        'registro', json_build_object(
            'proveedor', v_proveedor,
            'movimientos', v_movimientos
        )
    );
END;
$function$;
