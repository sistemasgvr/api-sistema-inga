CREATE OR REPLACE FUNCTION auth_obtener_usuario(p_id BIGINT)
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
            u.username,
            u.email,
            u.nombres,
            u.apellidos,
            u.telefono,
            u.id_sucursal_default,
            u.estado,
            u.fecha_creacion,
            u.fecha_modificacion,
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