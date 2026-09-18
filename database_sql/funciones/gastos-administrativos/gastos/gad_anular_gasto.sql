-- Anulo un gasto administrativo (baja lógica, estado = 0).
--
-- Mismo criterio que en planilla: no borro ni dejo rastro perdido. El gasto
-- sigue en la tabla con estado = 0 y el motivo anexado a la observación.
--
-- Bloqueo la anulación si fue en efectivo y su turno ya se cerró: quitarle un
-- egreso a un turno arqueado invalidaría la diferencia que quedó firmada.
CREATE OR REPLACE FUNCTION gad_anular_gasto(
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

    SELECT g.medio_pago, g.id_turno
    INTO v_medio, v_id_turno
    FROM gad_gasto g
    WHERE g.id = p_id AND g.estado = 1;

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
                'error', 'No se puede anular: el gasto fue en efectivo y su turno de caja ya está cerrado y arqueado.'
            );
        END IF;
    END IF;

    UPDATE gad_gasto
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
