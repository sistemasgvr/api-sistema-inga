-- Registro un abono: el consorcio paga, o se le descuenta de planilla al
-- trabajador. Reduce lo que nos debe.
--
-- Es el movimiento que el administrador hace cuando la empresa abona, a inicios
-- de cada mes, después de compartirle el reporte de la quincena.
--
-- Regla del alcance: **el abono no puede superar el saldo deudor**. Pagar más
-- de lo que se debe dejaría el saldo en negativo, que en este módulo no
-- significa nada: la cuenta es "cuánto nos deben", no una cuenta corriente con
-- saldo a favor. Si de verdad hubo un pago de más, se corrige con un ajuste
-- (tipo 3), que queda explícito en el historial.
--
-- A diferencia de CxP, acá NO exijo turno de caja: el abono del consorcio llega
-- por transferencia o descuento de planilla, no entra al cajón del día.
CREATE OR REPLACE FUNCTION cxc_registrar_abono(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_fecha_movimiento DATE DEFAULT NULL,
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
    v_persona RECORD;
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

    v_saldo := v_saldo_actual - p_monto;
    v_quincena := CASE WHEN EXTRACT(DAY FROM v_fecha) <= 15 THEN 1 ELSE 2 END;

    INSERT INTO cxc_movimiento (
        id_persona, id_convenio, tipo_movimiento, monto, saldo_resultante,
        anio, mes, quincena, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_persona, v_persona.id_convenio, 2, p_monto, v_saldo,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        v_quincena,
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cxc_obtener_movimiento(v_id);
END;
$function$;
