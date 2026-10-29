DROP FUNCTION IF EXISTS pro_obtener_categoria(p_id BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION pro_obtener_categoria(p_id BIGINT, p_id_empresa BIGINT DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.nombre,
            c.descripcion,
            c.es_carta,
            c.orden,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um2.nombres AS nombre_usuario_modificacion
        FROM pro_categoria c
        LEFT JOIN auth_usuario_datos uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario_datos um2 ON c.id_usuario_modificacion = um2.id
        WHERE c.id = p_id
          AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;