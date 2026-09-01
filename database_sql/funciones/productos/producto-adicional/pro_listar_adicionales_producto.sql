CREATE OR REPLACE FUNCTION pro_listar_adicionales_producto(p_id_producto BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
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
        WHERE a.id_producto = p_id_producto AND a.estado = 1
        ORDER BY a.nombre ASC
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
