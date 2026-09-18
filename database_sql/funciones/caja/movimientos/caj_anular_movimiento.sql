-- Anulo un movimiento de caja (baja lógica, estado = 0).
--
-- Hace falta porque el cajero se equivoca: escribe 500 en vez de 50 y necesita
-- corregirlo. No lo borro de verdad ni dejo editarlo, para que quede el rastro
-- de que existió y quién lo anuló.
--
-- Solo se puede anular con el turno todavía abierto. Una vez cerrado, los
-- números ya se compararon contra el conteo físico y tocarlos rompería el
-- arqueo que quedó guardado.
CREATE OR REPLACE FUNCTION caj_anular_movimiento(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_turno BIGINT;
    v_estado_turno SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT m.id_turno, t.estado_turno
    INTO v_id_turno, v_estado_turno
    FROM caj_movimiento m
    INNER JOIN caj_turno t ON m.id_turno = t.id
    WHERE m.id = p_id AND m.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado_turno = 2 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede anular un movimiento de un turno ya cerrado'
        );
    END IF;

    UPDATE caj_movimiento
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
