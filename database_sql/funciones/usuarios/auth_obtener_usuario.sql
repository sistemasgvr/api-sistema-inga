DROP FUNCTION IF EXISTS auth_obtener_usuario(p_id BIGINT);
DROP FUNCTION IF EXISTS auth_obtener_usuario(p_id BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION auth_obtener_usuario(p_id BIGINT, p_id_empresa BIGINT DEFAULT NULL)
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
            u.id_trabajador,
            u.username,
            u.email,
            u.nombres,
            u.apellidos,
            u.telefono,
            u.id_sucursal_default,
            u.es_super_admin,
            u.estado,
            u.fecha_creacion,
            u.fecha_modificacion,
            u.id_empresa,
            auth_sucursales_usuario(u.id) AS sucursales,
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
        FROM auth_usuario_datos u
        WHERE u.id = p_id
          AND (p_id_empresa IS NULL OR u.id_empresa = p_id_empresa)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;