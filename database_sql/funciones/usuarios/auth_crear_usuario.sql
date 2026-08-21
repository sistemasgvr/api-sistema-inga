CREATE OR REPLACE FUNCTION auth_crear_usuario(
    p_username VARCHAR,
    p_email VARCHAR,
    p_password_hash VARCHAR,
    p_nombres VARCHAR,
    p_apellidos VARCHAR,
    p_telefono VARCHAR DEFAULT NULL,
    p_pin_hash VARCHAR DEFAULT NULL,
    p_id_sucursal_default BIGINT DEFAULT NULL,
    p_roles_ids JSON DEFAULT '[]'::JSON,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_usuario BIGINT;
    v_role_id BIGINT;
    v_registro JSON;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF EXISTS (SELECT 1 FROM auth_usuario WHERE username = p_username) THEN
        RAISE EXCEPTION 'El nombre de usuario % ya se encuentra registrado.', p_username;
    END IF;

    IF EXISTS (SELECT 1 FROM auth_usuario WHERE email = p_email) THEN
        RAISE EXCEPTION 'El correo electrónico % ya se encuentra registrado.', p_email;
    END IF;

    INSERT INTO auth_usuario (
        username,
        email,
        password_hash,
        pin_hash,
        nombres,
        apellidos,
        telefono,
        id_sucursal_default,
        es_super_admin,
        estado
    ) VALUES (
        p_username,
        p_email,
        p_password_hash,
        p_pin_hash,
        p_nombres,
        p_apellidos,
        p_telefono,
        p_id_sucursal_default,
        FALSE,
        1
    )
    RETURNING id INTO v_id_usuario;

    IF p_roles_ids IS NOT NULL AND json_array_length(p_roles_ids) > 0 THEN
        FOR v_role_id IN SELECT json_array_elements_text(p_roles_ids)::BIGINT LOOP
            INSERT INTO auth_usuario_rol (
                id_usuario,
                id_rol,
                estado,
                id_usuario_creacion
            )
            VALUES (
                v_id_usuario,
                v_role_id,
                1,
                p_id_usuario_auditoria
            )
            ON CONFLICT (id_usuario, id_rol) DO UPDATE
            SET estado = 1,
                id_usuario_modificacion = p_id_usuario_auditoria;
        END LOOP;
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
        WHERE u.id = v_id_usuario
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
