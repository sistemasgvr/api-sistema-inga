-- Anulo una línea del gasto del día (baja lógica).
--
-- Lo delicado acá es el reverso: si la línea era a crédito, generó un cargo en
-- CxP y hay que deshacerlo, o la deuda con el proveedor quedaría inflada.
--
-- Uso `cxp_anular_movimiento`, que solo permite anular el ÚLTIMO movimiento del
-- proveedor. Si desde que se registró esta compra ya hubo otros movimientos
-- (otra compra o un abono), la anulación falla — y está bien que falle: anular
-- uno del medio dejaría mintiendo los saldos guardados de los posteriores.
-- En ese caso el mensaje le dice al usuario que use un ajuste en CxP.
--
-- También bloqueo anular una línea en efectivo cuyo turno ya se cerró: ese
-- turno se arqueó contra el conteo físico.
CREATE OR REPLACE FUNCTION gdo_anular_linea(
    p_id BIGINT,
    p_motivo VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_linea RECORD;
    v_estado_turno SMALLINT;
    v_reverso JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT det.id, det.id_gasto_dia, det.forma_pago, det.id_cxp_movimiento,
           dia.id_turno
    INTO v_linea
    FROM gdo_gasto_detalle det
    INNER JOIN gdo_gasto_dia dia ON det.id_gasto_dia = dia.id
    WHERE det.id = p_id AND det.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La línea no existe o ya fue anulada', 'registro', NULL);
    END IF;

    IF v_linea.forma_pago = 1 AND v_linea.id_turno IS NOT NULL THEN
        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = v_linea.id_turno;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'error', 'No se puede anular: la compra fue en efectivo y el turno de caja del día ya está cerrado y arqueado.',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Reverso del cargo en CxP.
    IF v_linea.id_cxp_movimiento IS NOT NULL THEN
        v_reverso := cxp_anular_movimiento(
            v_linea.id_cxp_movimiento,
            'Anulación de compra diaria',
            p_id_usuario_auditoria
        )::JSONB;

        IF (v_reverso->>'eliminado')::BOOLEAN = FALSE THEN
            RETURN json_build_object(
                'error', COALESCE(
                    v_reverso->>'error',
                    'No se pudo revertir la deuda generada en cuentas por pagar.'
                ),
                'registro', NULL
            );
        END IF;
    END IF;

    UPDATE gdo_gasto_detalle
    SET estado = 0,
        observacion = TRIM(BOTH ' ' FROM
            COALESCE(observacion || ' | ', '') ||
            'ANULADA: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado')
        ),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    PERFORM gdo_recalcular_totales_dia(v_linea.id_gasto_dia);

    RETURN gdo_obtener_dia(v_linea.id_gasto_dia);
END;
$function$;
