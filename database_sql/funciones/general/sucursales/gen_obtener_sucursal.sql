CREATE OR REPLACE FUNCTION gen_obtener_sucursal(p_id BIGINT)
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
            s.id,
            s.id_empresa,
            s.codigo,
            s.nombre,
            s.direccion,
            s.telefono,
            s.id_distrito,
            s.es_principal,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            (
                SELECT COUNT(*)
                FROM auth_usuario u
                WHERE u.id_sucursal_default = s.id AND u.estado = 1
            ) AS total_usuarios
        FROM gen_sucursal s
        WHERE s.id = p_id AND s.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
