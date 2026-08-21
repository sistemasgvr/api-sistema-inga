CREATE OR REPLACE FUNCTION auth_obtener_permisos_usuario(p_id_usuario BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_permisos JSON;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT COALESCE(json_agg(DISTINCT p.codigo ORDER BY p.codigo), '[]'::JSON)
    INTO v_permisos
    FROM auth_usuario_rol ur
    INNER JOIN auth_rol r ON ur.id_rol = r.id
    INNER JOIN auth_rol_permiso rp ON rp.id_rol = r.id
    INNER JOIN auth_permiso p ON rp.id_permiso = p.id
    WHERE ur.id_usuario = p_id_usuario
      AND ur.estado = 1
      AND r.estado = 1
      AND rp.estado = 1
      AND p.estado = 1;

    RETURN json_build_object('permisos', v_permisos);
END;
$function$;