-- Anulo un pago de planilla (baja lógica, estado = 0).
--
-- Hace falta porque el cajero se equivoca: escribe 800 en vez de 80, o carga el
-- pago al trabajador equivocado. No lo borro ni dejo editarlo, para que quede
-- el rastro de que existió y quién lo anuló.
--
-- Al anularlo, el índice parcial uq_pla_pago_quincena (que solo mira los
-- registros con estado = 1) libera esa quincena y permite registrar el pago
-- corregido. Por eso el índice es parcial y no una constraint normal.
--
-- Si el pago fue en efectivo contra un turno ya cerrado, bloqueo la anulación:
-- ese turno ya se arqueó contra el conteo físico y quitarle un egreso ahora
-- invalidaría la diferencia que quedó firmada.
CREATE OR REPLACE FUNCTION pla_anular_pago(
    p_id BIGINT,
    p_motivo VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_medio SMALLINT;
    v_id_turno BIGINT;
    v_estado_turno SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT p.medio_pago, p.id_turno
    INTO v_medio, v_id_turno
    FROM pla_pago p
    WHERE p.id = p_id AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_medio = 1 AND v_id_turno IS NOT NULL THEN
        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = v_id_turno;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id,
                'error', 'No se puede anular: el pago fue en efectivo y su turno de caja ya está cerrado y arqueado.'
            );
        END IF;
    END IF;

    UPDATE pla_pago
    SET estado = 0,
        -- Conservo la observación previa y le agrego el motivo de anulación:
        -- las dos son parte de la historia del registro.
        observacion = TRIM(BOTH ' ' FROM
            COALESCE(observacion || ' | ', '') ||
            'ANULADO: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado')
        ),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
