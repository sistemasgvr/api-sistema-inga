CREATE OR REPLACE FUNCTION auth_actualizar_usuario(
    p_id BIGINT,
    p_username VARCHAR DEFAULT NULL,
    p_password_hash VARCHAR DEFAULT NULL,
    p_pin_hash VARCHAR DEFAULT NULL,
    p_roles_ids JSON DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_role_id BIGINT;
    v_registro JSON;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF NOT EXISTS (SELECT 1 FROM auth_usuario_datos WHERE id = p_id AND estado = 1) THEN
        RAISE EXCEPTION 'Usuario no encontrado o inactivo.';
    END IF;

    IF p_username IS NOT NULL AND EXISTS (SELECT 1 FROM auth_usuario_datos WHERE username = p_username AND id <> p_id) THEN
        RAISE EXCEPTION 'El nombre de usuario % ya pertenece a otro registro.', p_username;
    END IF;


    UPDATE auth_usuario
    SET 
        username = COALESCE(p_username, username),
        password_hash = COALESCE(p_password_hash, password_hash),
        pin_hash = COALESCE(p_pin_hash, pin_hash)
    WHERE id = p_id;

    IF p_roles_ids IS NOT NULL THEN
        UPDATE auth_usuario_rol
        SET estado = 0
        WHERE id_usuario = p_id;

        IF json_array_length(p_roles_ids) > 0 THEN
            FOR v_role_id IN SELECT json_array_elements_text(p_roles_ids)::BIGINT LOOP
                IF EXISTS (SELECT 1 FROM auth_usuario_rol WHERE id_usuario = p_id AND id_rol = v_role_id) THEN
                    UPDATE auth_usuario_rol
                    SET estado = 1
                    WHERE id_usuario = p_id AND id_rol = v_role_id;
                ELSE
                    INSERT INTO auth_usuario_rol (id_usuario, id_rol, estado)
                    VALUES (p_id, v_role_id, 1);
                END IF;
            END LOOP;
        END IF;
    END IF;

    RETURN auth_obtener_usuario(p_id);
END;
$function$;
