DROP FUNCTION IF EXISTS cxc_registrar_abono(BIGINT, NUMERIC, DATE, VARCHAR, BIGINT);
CREATE OR REPLACE FUNCTION cxc_registrar_abono(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_fecha_movimiento DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_pedido BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
    v_saldo_actual NUMERIC(12,2);
    v_saldo NUMERIC(12,2);
    v_persona RECORD;
    v_quincena SMALLINT;
    v_observacion VARCHAR;
    v_codigo VARCHAR;
    v_id_persona_pedido BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_movimiento, CURRENT_DATE);
    v_observacion := NULLIF(TRIM(p_observacion), '');

    SELECT
        p.es_cliente,
        p.id_convenio,
        COALESCE(
            NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
            p.razon_social
        ) AS nombre
    INTO v_persona
    FROM cli_persona p
    WHERE p.id = p_id_persona AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La persona no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_persona.es_cliente = FALSE THEN
        RETURN json_build_object(
            'error', 'Solo se puede abonar a una persona marcada como cliente',
            'registro', NULL
        );
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto del abono debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede registrar un abono con fecha futura', 'registro', NULL);
    END IF;

    v_saldo_actual := cxc_calcular_saldo_persona(p_id_persona);

    IF v_saldo_actual <= 0 THEN
        RETURN json_build_object(
            'error', v_persona.nombre || ' no tiene deuda pendiente: la cuenta está en cero.',
            'registro', NULL
        );
    END IF;

    IF p_monto > v_saldo_actual THEN
        RETURN json_build_object(
            'error', 'El abono supera la deuda de ' || v_persona.nombre ||
                     ' (S/ ' || TO_CHAR(v_saldo_actual, 'FM999999990.00') ||
                     '). Si pagó de más, regístralo como ajuste.',
            'registro', NULL
        );
    END IF;

    -- Si es una corrección, el pedido tiene que existir y ser de esta misma persona:
    -- si no, el abono queda flotando sin rastro del crédito que está corrigiendo.
    IF p_id_pedido IS NOT NULL THEN
        SELECT pd.codigo, pd.id_persona INTO v_codigo, v_id_persona_pedido
          FROM ven_pedido pd WHERE pd.id = p_id_pedido;
        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El pedido indicado no existe', 'registro', NULL);
        END IF;
        -- IS DISTINCT FROM y no "<>" a propósito: un pedido sin id_persona tampoco
        -- es de este cliente, y con "<>" el NULL se colaría. Todo pedido que genera
        -- un cargo a crédito tiene persona puesta (la asigna ven_pedido_cobrar), así
        -- que si no la tiene es que el vínculo no es válido.
        IF v_id_persona_pedido IS DISTINCT FROM p_id_persona THEN
            RETURN json_build_object(
                'error', 'El pedido ' || v_codigo || ' no está vinculado a este cliente',
                'registro', NULL
            );
        END IF;
        -- Si el cajero no escribió nada, la observación explica sola qué es este abono.
        IF v_observacion IS NULL THEN
            v_observacion := 'Corrección de crédito — Pedido ' || v_codigo;
        END IF;
    END IF;

    v_saldo := v_saldo_actual - p_monto;
    v_quincena := CASE WHEN EXTRACT(DAY FROM v_fecha) <= 15 THEN 1 ELSE 2 END;

    INSERT INTO cxc_movimiento (
        id_persona, id_convenio, id_pedido, tipo_movimiento, monto, saldo_resultante,
        anio, mes, quincena, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_persona, v_persona.id_convenio, p_id_pedido, 2, p_monto, v_saldo,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        v_quincena,
        v_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cxc_obtener_movimiento(v_id);
END;
$function$;
