CREATE OR REPLACE FUNCTION pro_obtener_adicional(p_id BIGINT)
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
            a.id,
            a.id_producto,
            a.nombre,
            a.precio_adicional,
            a.id_producto_insumo,
            pi.nombre AS nombre_insumo,
            a.cantidad_insumo,
            a.id_unidad_medida,
            um.simbolo AS simbolo_unidad,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion
        FROM pro_adicional a
        LEFT JOIN pro_producto pi ON a.id_producto_insumo = pi.id
        LEFT JOIN pro_unidad_medida um ON a.id_unidad_medida = um.id
        WHERE a.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
