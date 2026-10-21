-- Registro un consumo a crédito: aumenta lo que una persona nos debe. Se llama desde el módulo de ventas cuando se cierra un pedido a crédito.
drop ADD FUNCTION IF EXISTS cxc_registrar_consumo(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_fecha_movimiento DATE DEFAULT NULL,
    p_id_pedido BIGINT DEFAULT NULL,
    p_id_pago BIGINT DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
);
DROP FUNCTION IF EXISTS cxc_registrar_consumo(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_fecha_movimiento DATE,
    p_id_pedido BIGINT,
    p_id_pago BIGINT,
    p_observacion VARCHAR,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION cxc_registrar_consumo(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_fecha_movimiento DATE DEFAULT NULL,
    p_id_pedido BIGINT DEFAULT NULL,
    p_id_pago BIGINT DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
    v_persona RECORD;
    v_limite NUMERIC(12,2);
    v_saldo NUMERIC(12,2);
    v_quincena SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_movimiento, CURRENT_DATE);

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
            'error', 'Solo se puede registrar consumo a crédito a una persona marcada como cliente',
            'registro', NULL
        );
    END IF;

    IF v_persona.id_convenio IS NULL THEN
        RETURN json_build_object(
            'error', v_persona.nombre || ' no tiene convenio asignado. El crédito del consorcio se carga a una empresa.',
            'registro', NULL
        );
    END IF;

    SELECT limite_credito INTO v_limite
    FROM cli_convenio WHERE id = v_persona.id_convenio AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'El convenio de ' || v_persona.nombre || ' está inactivo. Reactívalo o asígnale otro.',
            'registro', NULL
        );
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto del consumo debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede registrar un consumo con fecha futura', 'registro', NULL);
    END IF;

    v_saldo := cxc_calcular_saldo_persona(p_id_persona) + p_monto;
    v_quincena := CASE WHEN EXTRACT(DAY FROM v_fecha) <= 15 THEN 1 ELSE 2 END;

    INSERT INTO cxc_movimiento (
        id_persona, id_convenio, id_pedido, id_pago,
        tipo_movimiento, monto, saldo_resultante,
        anio, mes, quincena, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_persona, v_persona.id_convenio, p_id_pedido, p_id_pago,
        1, p_monto, v_saldo,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        v_quincena,
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Devuelvo el movimiento más la advertencia de límite, si aplica.
    -- Un límite en 0 significa "sin tope definido", así que no advierto.
    RETURN (
        SELECT jsonb_set(
            cxc_obtener_movimiento(v_id)::JSONB,
            '{supera_limite}',
            to_jsonb(COALESCE(v_limite, 0) > 0 AND v_saldo > v_limite)
        )::JSON
    );
END;
$function$;
