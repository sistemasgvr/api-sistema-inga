DROP FUNCTION IF EXISTS auth_crear_usuario(
    p_username VARCHAR,
    p_id_trabajador BIGINT,
    p_password_hash VARCHAR,
    p_pin_hash VARCHAR,
    p_roles_ids JSON,
    p_id_usuario_auditoria BIGINT
);
DROP FUNCTION IF EXISTS auth_crear_usuario(
    p_username VARCHAR,
    p_id_trabajador BIGINT,
    p_password_hash VARCHAR,
    p_pin_hash VARCHAR,
    p_roles_ids JSON,
    p_id_usuario_auditoria BIGINT,
    p_sucursales JSON,
    p_id_sucursal_predeterminada BIGINT
);
CREATE OR REPLACE FUNCTION auth_crear_usuario(
    p_username VARCHAR,
    p_id_trabajador BIGINT,
    p_password_hash VARCHAR,
    p_pin_hash VARCHAR DEFAULT NULL,
    p_roles_ids JSON DEFAULT '[]'::JSON,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    -- Sucursales de la empresa del trabajador; sin ellas, la sucursal del trabajador.
    p_sucursales JSON DEFAULT NULL,
    p_id_sucursal_predeterminada BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_usuario BIGINT;
    v_role_id BIGINT;
    v_registro JSON;
    v_sucursal_trabajador BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF EXISTS (SELECT 1 FROM auth_usuario_datos WHERE username = p_username) THEN
        RAISE EXCEPTION 'El nombre de usuario % ya se encuentra registrado.', p_username;
    END IF;

    SELECT id_sucursal INTO v_sucursal_trabajador
    FROM pla_trabajador WHERE id = p_id_trabajador AND estado = 1 AND email IS NOT NULL FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Seleccione un trabajador activo con correo electrónico.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pla_trabajador WHERE id = p_id_trabajador AND id_empresa IS NOT NULL) THEN
        RAISE EXCEPTION 'El trabajador no tiene empresa asignada.';
    END IF;
    IF EXISTS (SELECT 1 FROM auth_usuario WHERE id_trabajador = p_id_trabajador) THEN
        RAISE EXCEPTION 'El trabajador ya se encuentra registrado con un usuario.';
    END IF;

    INSERT INTO auth_usuario (
        username,
        id_trabajador,
        password_hash,
        pin_hash,
        es_super_admin,
        estado
    ) VALUES (
        p_username,
        p_id_trabajador,
        p_password_hash,
        p_pin_hash,
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

    IF p_sucursales IS NOT NULL AND json_array_length(p_sucursales) > 0 THEN
        PERFORM auth_asignar_sucursales_usuario(v_id_usuario, p_sucursales, p_id_sucursal_predeterminada, p_id_usuario_auditoria);
    ELSIF v_sucursal_trabajador IS NOT NULL THEN
        PERFORM auth_asignar_sucursales_usuario(v_id_usuario, json_build_array(v_sucursal_trabajador), v_sucursal_trabajador, p_id_usuario_auditoria);
    END IF;

    RETURN auth_obtener_usuario(v_id_usuario);
END;
$function$;
