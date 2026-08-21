CREATE OR REPLACE FUNCTION auth_eliminar_usuario(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_es_super_admin BOOLEAN;
    v_es_admin BOOLEAN;
    v_total_admins_activos INT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT es_super_admin INTO v_es_super_admin
    FROM auth_usuario
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'eliminado', FALSE, 
            'id', p_id, 
            'error', 'El usuario especificado no existe o ya se encuentra inactivo.'
        );
    END IF;

    IF v_es_super_admin IS TRUE THEN
        RETURN json_build_object(
            'eliminado', FALSE, 
            'id', p_id, 
            'error', 'Acción denegada: El usuario Propietario (Super Admin) está protegido por el sistema.'
        );
    END IF;

    SELECT EXISTS (
        SELECT 1 
        FROM auth_usuario_rol ur
        INNER JOIN auth_rol r ON ur.id_rol = r.id
        WHERE ur.id_usuario = p_id AND ur.estado = 1 AND r.codigo = 'ADMIN' AND r.estado = 1
    ) INTO v_es_admin;

    IF v_es_admin IS TRUE THEN
        SELECT COUNT(DISTINCT ur.id_usuario) INTO v_total_admins_activos
        FROM auth_usuario_rol ur
        INNER JOIN auth_rol r ON ur.id_rol = r.id
        INNER JOIN auth_usuario u ON ur.id_usuario = u.id
        WHERE r.codigo = 'ADMIN' AND r.estado = 1 
          AND ur.estado = 1 
          AND u.estado = 1;

        IF v_total_admins_activos <= 1 THEN
            RETURN json_build_object(
                'eliminado', FALSE, 
                'id', p_id, 
                'error', 'Acción denegada: No es posible desactivar al único Administrador activo del sistema.'
            );
        END IF;
    END IF;

    UPDATE auth_usuario
    SET estado = 0
    WHERE id = p_id;

    UPDATE auth_sesion
    SET estado = 0
    WHERE id_usuario = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id, 'error', NULL);
END;
$function$;