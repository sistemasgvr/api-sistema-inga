-- Reactivo una caja dada de baja.
CREATE OR REPLACE FUNCTION caj_activar_caja(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE caj_caja
    SET estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 0;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;
