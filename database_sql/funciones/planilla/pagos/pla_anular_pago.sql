-- Anulo un pago de planilla (baja lógica); el índice parcial uq_pla_pago_quincena libera la quincena
-- para registrar el pago corregido. No si fue en efectivo y su turno ya se cerró.
DROP FUNCTION IF EXISTS pla_anular_pago(
    p_id BIGINT,
    p_motivo VARCHAR,
    p_id_usuario_auditoria BIGINT
);
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
        observacion = TRIM(BOTH ' ' FROM
            COALESCE(observacion || ' | ', '') ||
            'ANULADO: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado')
        ),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
