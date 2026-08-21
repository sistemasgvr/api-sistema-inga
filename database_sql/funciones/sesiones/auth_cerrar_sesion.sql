CREATE OR REPLACE FUNCTION auth_cerrar_sesion(
    p_id_sesion BIGINT,
    p_id_usuario BIGINT
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    UPDATE auth_sesion
    SET estado = 0,
        fecha_fin = NOW()
    WHERE id = p_id_sesion AND id_usuario = p_id_usuario AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('cerrada', FALSE, 'id', p_id_sesion);
    END IF;

    RETURN json_build_object('cerrada', TRUE, 'id', p_id_sesion);
END;
$function$;