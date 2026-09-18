-- Registro un abono: el pago semanal que le hacemos a un proveedor.
--
-- Es el movimiento que el administrador hace cada semana (S/1000 al de pollo,
-- S/800 al de carnes, etc. según lo consumido).
--
-- Dos reglas que impongo:
--
-- 1. **El abono no puede superar la deuda.** Pagar más de lo que se debe deja
--    el saldo en negativo, que en este módulo no significa nada: la cuenta es
--    "cuánto le debemos", no una cuenta corriente con saldo a favor. Si de
--    verdad hubo un pago de más, eso se corrige con un ajuste (tipo 3), que
--    queda explícito en el historial.
--
-- 2. **Si el abono sale en efectivo, exige turno de caja abierto.** Ese dinero
--    sale del cajón y sin el vínculo el cuadre del día no cerraría. Misma
--    regla que en planilla (M17) y gastos administrativos (M16).
CREATE OR REPLACE FUNCTION cxp_registrar_abono(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_medio_pago SMALLINT DEFAULT 1,
    p_id_turno BIGINT DEFAULT NULL,
    p_fecha_movimiento DATE DEFAULT NULL,
    p_num_comprobante VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
    v_saldo_actual NUMERIC(12,2);
    v_saldo NUMERIC(12,2);
    v_es_proveedor BOOLEAN;
    v_estado_turno SMALLINT;
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_movimiento, CURRENT_DATE);

    SELECT
        es_proveedor,
        COALESCE(
            NULLIF(TRIM(COALESCE(nombres, '') || ' ' || COALESCE(apellido_paterno, '')), ''),
            razon_social
        )
    INTO v_es_proveedor, v_nombre
    FROM cli_persona WHERE id = p_id_persona AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La persona indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_es_proveedor = FALSE THEN
        RETURN json_build_object(
            'error', 'Solo se puede abonar a una persona marcada como proveedor',
            'registro', NULL
        );
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto del abono debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede registrar un abono con fecha futura', 'registro', NULL);
    END IF;

    IF COALESCE(p_medio_pago, 1) NOT IN (1, 2, 3) THEN
        RETURN json_build_object(
            'error', 'El medio de pago debe ser efectivo, Yape o tarjeta/transferencia',
            'registro', NULL
        );
    END IF;

    v_saldo_actual := cxp_calcular_saldo_proveedor(p_id_persona);

    IF v_saldo_actual <= 0 THEN
        RETURN json_build_object(
            'error', 'No hay deuda pendiente con ' || v_nombre || ': la cuenta está en cero.',
            'registro', NULL
        );
    END IF;

    IF p_monto > v_saldo_actual THEN
        RETURN json_build_object(
            'error', 'El abono supera la deuda pendiente con ' || v_nombre ||
                     ' (S/ ' || TO_CHAR(v_saldo_actual, 'FM999999990.00') ||
                     '). Si pagaste de más, regístralo como ajuste.',
            'registro', NULL
        );
    END IF;

    IF COALESCE(p_medio_pago, 1) = 1 THEN
        IF p_id_turno IS NULL THEN
            RETURN json_build_object(
                'error', 'Un abono en efectivo debe registrarse contra un turno de caja abierto',
                'registro', NULL
            );
        END IF;

        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = p_id_turno AND estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El turno de caja indicado no existe', 'registro', NULL);
        END IF;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'error', 'No se puede registrar el abono: el turno de caja ya está cerrado',
                'registro', NULL
            );
        END IF;
    END IF;

    v_saldo := v_saldo_actual - p_monto;

    INSERT INTO cxp_movimiento (
        id_persona, id_turno, tipo_movimiento, monto, saldo_resultante,
        medio_pago, fecha_movimiento, anio, mes, semana,
        num_comprobante, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_persona, p_id_turno, 2, p_monto, v_saldo,
        COALESCE(p_medio_pago, 1),
        v_fecha,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        EXTRACT(WEEK FROM v_fecha)::SMALLINT,
        NULLIF(TRIM(p_num_comprobante), ''),
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cxp_obtener_movimiento(v_id);
END;
$function$;
