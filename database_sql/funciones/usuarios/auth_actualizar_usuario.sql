CREATE OR REPLACE FUNCTION auth_actualizar_usuario(
    p_id BIGINT,
    p_username VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_password_hash VARCHAR DEFAULT NULL,
    p_pin_hash VARCHAR DEFAULT NULL,
    p_nombres VARCHAR DEFAULT NULL,
    p_apellidos VARCHAR DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_id_sucursal_default BIGINT DEFAULT NULL,
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

    IF NOT EXISTS (SELECT 1 FROM auth_usuario WHERE id = p_id AND estado = 1) THEN
        RAISE EXCEPTION 'Usuario no encontrado o inactivo.';
    END IF;

    IF p_username IS NOT NULL AND EXISTS (SELECT 1 FROM auth_usuario WHERE username = p_username AND id <> p_id) THEN
        RAISE EXCEPTION 'El nombre de usuario % ya pertenece a otro registro.', p_username;
    END IF;

    IF p_email IS NOT NULL AND EXISTS (SELECT 1 FROM auth_usuario WHERE email = p_email AND id <> p_id) THEN
        RAISE EXCEPTION 'El correo electrónico % ya pertenece a otro registro.', p_email;
    END IF;

    UPDATE auth_usuario
    SET 
        username = COALESCE(p_username, username),
        email = COALESCE(p_email, email),
        password_hash = COALESCE(p_password_hash, password_hash),
        pin_hash = COALESCE(p_pin_hash, pin_hash),
        nombres = COALESCE(p_nombres, nombres),
        apellidos = COALESCE(p_apellidos, apellidos),
        telefono = COALESCE(p_telefono, telefono),
        id_sucursal_default = COALESCE(p_id_sucursal_default, id_sucursal_default)
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

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT 
            u.id, 
            u.username, 
            u.email, 
            u.nombres, 
            u.apellidos, 
            u.telefono,
            u.id_sucursal_default, 
            u.es_super_admin, 
            u.estado, 
            u.fecha_creacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', r.id, 
                    'codigo', r.codigo, 
                    'nombre', r.nombre
                )), '[]'::JSON)
                FROM auth_usuario_rol ur
                INNER JOIN auth_rol r ON ur.id_rol = r.id
                WHERE ur.id_usuario = u.id AND ur.estado = 1 AND r.estado = 1
            ) AS roles
        FROM auth_usuario u
        WHERE u.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
