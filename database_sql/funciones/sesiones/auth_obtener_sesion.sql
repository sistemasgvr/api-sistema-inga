CREATE OR REPLACE FUNCTION auth_obtener_sesion(p_refresh_token_hash VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            u.id,
            u.email AS correo,
            u.username,
            u.nombres,
            u.apellidos,
            (
                SELECT COALESCE(json_agg(DISTINCT p.codigo ORDER BY p.codigo), '[]'::JSON)
                FROM auth_usuario_rol ur
                INNER JOIN auth_rol r ON ur.id_rol = r.id
                INNER JOIN auth_rol_permiso rp ON rp.id_rol = r.id
                INNER JOIN auth_permiso p ON rp.id_permiso = p.id
                WHERE ur.id_usuario = u.id AND ur.estado = 1 AND r.estado = 1 AND rp.estado = 1 AND p.estado = 1
            ) AS permisos,
            json_build_object(
                'id', s.id,
                'id_usuario', u.id,
                'nombre_usuario', u.username,
                'correo', u.email,
                'fecha_inicio', s.fecha_inicio
            ) AS sesion
        FROM auth_sesion s
        INNER JOIN auth_usuario u ON s.id_usuario = u.id
        WHERE s.refresh_token_hash = p_refresh_token_hash 
          AND s.estado = 1 
          AND s.fecha_expiracion > NOW()
          AND u.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;