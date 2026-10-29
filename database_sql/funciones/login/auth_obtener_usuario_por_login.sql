DROP FUNCTION IF EXISTS auth_obtener_usuario_por_login(p_login VARCHAR);
CREATE OR REPLACE FUNCTION auth_obtener_usuario_por_login(p_login VARCHAR)
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
            u.password_hash,
            u.pin_hash,
            u.nombres,
            u.apellidos,
            u.telefono,
            u.id_sucursal_default,
            u.estado,
            u.es_super_admin,
            u.id_empresa,
            -- Empresa del usuario (la de su trabajador) y sucursales en las que puede trabajar.
            (
                SELECT json_build_object('id', e.id, 'ruc', e.ruc, 'razon_social', e.razon_social)
                FROM gen_empresa e
                WHERE e.id = u.id_empresa
            ) AS empresa,
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
        WHERE LOWER(u.email) = LOWER(p_login)
          AND u.estado = 1 AND u.estado_trabajador = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
