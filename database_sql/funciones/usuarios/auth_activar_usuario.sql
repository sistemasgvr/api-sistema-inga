CREATE OR REPLACE FUNCTION auth_activar_usuario(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF NOT EXISTS (SELECT 1 FROM auth_usuario_datos WHERE id = p_id AND estado_trabajador = 1) THEN
        RAISE EXCEPTION 'El trabajador debe estar activo para activar su usuario.';
    END IF;
    UPDATE auth_usuario
    SET estado = 1
    WHERE id = p_id AND estado = 0;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;