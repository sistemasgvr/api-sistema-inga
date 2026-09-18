-- Registro un consumo a crédito: aumenta lo que una persona nos debe.
--
-- Esta es la función que **M12 va a llamar automáticamente** cuando un pedido
-- se cobre con medio_pago = 4 (crédito). Los parámetros p_id_pedido y p_id_pago
-- quedan listos para ese enlace; hoy llegan NULL porque M12 todavía no existe y
-- los consumos se cargan a mano.
--
-- La quincena la DEDUZCO de la fecha, no la pido: días 1-15 = quincena 1,
-- 16 en adelante = quincena 2. Es la regla que el esquema ya documenta en el
-- COMMENT de la columna, y el corte se comparte con cada empresa a inicios del
-- mes siguiente.
--
-- Dos validaciones que vienen del alcance:
--   1. La persona debe tener es_cliente = TRUE.
--   2. Debe tener un convenio ACTIVO. El crédito del consorcio es contra la
--      empresa, no contra la persona suelta.
--
-- Sobre el límite de crédito: advierto pero NO bloqueo. El alcance dice
-- "el sistema debe advertir o bloquear" y dejó la decisión abierta (§7). Elijo
-- advertir porque bloquear en caja, con el cliente esperando, es el peor lugar
-- para descubrir un tope. Devuelvo la bandera `supera_limite` para que la
-- pantalla lo muestre; si después deciden bloquear, es cambiar este IF.
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
