-- Registro un ajuste manual sobre la cuenta de una persona.
--
-- Es la válvula de escape: una nota de crédito, un consumo mal cargado que ya
-- no se puede anular porque la quincena se cerró, o un pago de más que hay que
-- devolver contra la cuenta.
--
-- Aquí repito la decisión que ya tomé en CxP, y por el mismo motivo: aunque el
-- esquema tiene el tipo 3 = "Ajuste", NO guardo el movimiento como tipo 3 con
-- monto negativo. cxc_calcular_saldo_persona suma el tipo 3 tal cual, así que un
-- ajuste negativo guardado como monto positivo contaría al revés y el saldo
-- mentiría.
--
-- Lo que hago: guardo el ajuste con el tipo que corresponde a su EFECTO real
--   p_monto > 0  → aumenta la deuda → tipo 1
--   p_monto < 0  → reduce la deuda  → tipo 2
-- y le pongo el prefijo "AJUSTE —" a la observación, para que en el estado de
-- cuenta se distinga a simple vista de un consumo o un abono normal.
--
-- Exijo observación obligatoria: un ajuste sin explicación es un agujero en la
-- auditoría.
CREATE OR REPLACE FUNCTION cxc_registrar_ajuste(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_observacion VARCHAR,
    p_fecha_movimiento DATE DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
    v_persona RECORD;
    v_saldo NUMERIC(12,2);
    v_tipo SMALLINT;
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
            'error', 'Solo se puede ajustar la cuenta de una persona marcada como cliente',
            'registro', NULL
        );
    END IF;

    IF p_monto IS NULL OR p_monto = 0 THEN
        RETURN json_build_object('error', 'El monto del ajuste no puede ser cero', 'registro', NULL);
    END IF;

    IF NULLIF(TRIM(COALESCE(p_observacion, '')), '') IS NULL THEN
        RETURN json_build_object(
            'error', 'El ajuste necesita una observación que explique el motivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede registrar un ajuste con fecha futura', 'registro', NULL);
    END IF;

    v_tipo := CASE WHEN p_monto > 0 THEN 1 ELSE 2 END;
    v_saldo := cxc_calcular_saldo_persona(p_id_persona) + p_monto;

    -- Un ajuste no debería dejar la cuenta en negativo: eso significaría que le
    -- estamos "debiendo" al cliente, algo que este módulo no modela.
    IF v_saldo < 0 THEN
        RETURN json_build_object(
            'error', 'El ajuste dejaría la cuenta de ' || v_persona.nombre ||
                     ' en negativo (S/ ' || TO_CHAR(v_saldo, 'FM999999990.00') || '). Revisa el monto.',
            'registro', NULL
        );
    END IF;

    v_quincena := CASE WHEN EXTRACT(DAY FROM v_fecha) <= 15 THEN 1 ELSE 2 END;

    INSERT INTO cxc_movimiento (
        id_persona, id_convenio, tipo_movimiento, monto, saldo_resultante,
        anio, mes, quincena, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_persona, v_persona.id_convenio, v_tipo, ABS(p_monto), v_saldo,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        v_quincena,
        'AJUSTE — ' || TRIM(p_observacion),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cxc_obtener_movimiento(v_id);
END;
$function$;
