-- Anulo un movimiento de CxP (baja lógica, estado = 0).
--
-- Solo permito anular el ÚLTIMO movimiento vigente del proveedor. Es la regla
-- más importante de esta función y merece explicación:
--
-- Cada movimiento guarda su saldo_resultante como una foto del momento. Si
-- anulara uno del medio, todas las fotos posteriores quedarían mintiendo: el
-- historial mostraría saldos que nunca existieron. Recalcular hacia adelante
-- sería posible, pero reescribir el histórico de una cuenta por pagar es justo
-- lo que uno no quiere en un módulo de deuda.
--
-- Anulando solo el último, el saldo siempre queda consistente. Para corregir
-- algo más viejo está el ajuste (tipo 3), que deja el rastro visible.
--
-- Además bloqueo la anulación de un abono en efectivo cuyo turno ya se cerró:
-- ese turno se arqueó contra el conteo físico.
CREATE OR REPLACE FUNCTION cxp_anular_movimiento(
    p_id BIGINT,
    p_motivo VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov RECORD;
    v_ultimo_id BIGINT;
    v_estado_turno SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT m.id, m.id_persona, m.medio_pago, m.id_turno, m.tipo_movimiento
    INTO v_mov
    FROM cxp_movimiento m
    WHERE m.id = p_id AND m.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    SELECT m.id INTO v_ultimo_id
    FROM cxp_movimiento m
    WHERE m.id_persona = v_mov.id_persona AND m.estado = 1
    ORDER BY m.fecha_movimiento DESC, m.id DESC
    LIMIT 1;

    IF v_ultimo_id <> p_id THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'Solo se puede anular el último movimiento del proveedor. ' ||
                     'Anular uno anterior dejaría los saldos del historial inconsistentes. ' ||
                     'Para corregirlo, registra un ajuste.'
        );
    END IF;

    IF v_mov.tipo_movimiento = 2 AND v_mov.medio_pago = 1 AND v_mov.id_turno IS NOT NULL THEN
        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = v_mov.id_turno;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id,
                'error', 'No se puede anular: el abono fue en efectivo y su turno de caja ya está cerrado y arqueado.'
            );
        END IF;
    END IF;

    UPDATE cxp_movimiento
    SET estado = 0,
        observacion = TRIM(BOTH ' ' FROM
            COALESCE(observacion || ' | ', '') ||
            'ANULADO: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado')
        ),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
