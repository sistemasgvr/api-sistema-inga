CREATE OR REPLACE FUNCTION auth_asignar_roles_usuario(
    p_id_usuario BIGINT,
    p_ids_roles BIGINT[],
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_rol BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF NOT EXISTS (SELECT 1 FROM auth_usuario WHERE id = p_id_usuario AND estado = 1) THEN
        RETURN json_build_object('error', 'El usuario especificado no existe o está inactivo', 'registro', NULL);
    END IF;

    UPDATE auth_usuario_rol
    SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id_usuario = p_id_usuario;

    FOREACH v_id_rol IN ARRAY p_ids_roles LOOP
        INSERT INTO auth_usuario_rol (
            id_usuario,
            id_rol,
            estado,
            id_usuario_creacion
        )
        VALUES (
            p_id_usuario,
            v_id_rol,
            1,
            p_id_usuario_auditoria
        )
        ON CONFLICT (id_usuario, id_rol) DO UPDATE
        SET estado = 1,
            id_usuario_modificacion = p_id_usuario_auditoria;
    END LOOP;

    RETURN json_build_object('actualizado', TRUE, 'id_usuario', p_id_usuario);
END;
$function$;
