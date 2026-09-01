CREATE OR REPLACE FUNCTION pro_obtener_categoria(p_id BIGINT)
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
            c.codigo,
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
        LEFT JOIN auth_usuario uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um2 ON c.id_usuario_modificacion = um2.id
        WHERE c.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
