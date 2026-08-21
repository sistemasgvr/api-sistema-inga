CREATE OR REPLACE FUNCTION auth_asignar_permisos_rol(
    p_id_rol BIGINT,
    p_ids_permisos BIGINT[],
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_permiso BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF NOT EXISTS (SELECT 1 FROM auth_rol WHERE id = p_id_rol AND estado = 1) THEN
        RETURN json_build_object('error', 'El rol especificado no existe o está inactivo', 'registro', NULL);
    END IF;

    UPDATE auth_rol_permiso
    SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id_rol = p_id_rol;

    FOREACH v_id_permiso IN ARRAY p_ids_permisos LOOP
        INSERT INTO auth_rol_permiso (
            id_rol, id_permiso, estado, id_usuario_creacion
        )
        VALUES (
            p_id_rol, v_id_permiso, 1, p_id_usuario_auditoria
        )
        ON CONFLICT (id_rol, id_permiso) DO UPDATE
        SET estado = 1,
            id_usuario_modificacion = p_id_usuario_auditoria;
    END LOOP;

    RETURN auth_obtener_rol(p_id_rol);
END;
$function$;