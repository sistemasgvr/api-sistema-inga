CREATE OR REPLACE FUNCTION auth_obtener_rol(p_id BIGINT)
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
            r.id,
            r.codigo,
            r.nombre,
            r.descripcion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', p.id,
                    'codigo', p.codigo,
                    'nombre', p.nombre,
                    'modulo', p.modulo
                ) ORDER BY p.modulo, p.codigo), '[]'::JSON)
                FROM auth_rol_permiso rp
                INNER JOIN auth_permiso p ON rp.id_permiso = p.id
                WHERE rp.id_rol = r.id AND rp.estado = 1 AND p.estado = 1
            ) AS permisos
        FROM auth_rol r
        WHERE r.id = p_id AND r.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;