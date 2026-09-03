CREATE OR REPLACE FUNCTION gen_activar_sucursal(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    UPDATE gen_sucursal
    SET estado = 1, id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 0;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;