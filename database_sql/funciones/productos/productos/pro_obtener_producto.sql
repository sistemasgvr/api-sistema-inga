CREATE OR REPLACE FUNCTION pro_obtener_producto(p_id BIGINT)
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
            p.id,
            p.id_subcategoria,
            sc.nombre AS nombre_subcategoria,
            sc.id_categoria,
            c.nombre AS nombre_categoria,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            um.simbolo AS simbolo_unidad,
            p.id_estacion,
            e.nombre AS nombre_estacion,
            p.id_almacen_stock,
            a.nombre AS nombre_almacen,
            p.codigo_interno,
            p.nombre,
            p.descripcion,
            p.tipo_producto,
            p.precio_venta,
            p.costo_receta_calculado,
            p.afecto_igv,
            p.controla_stock,
            p.disponible_venta,
            p.tiempo_prep_min,
            p.imagen_url,
            p.estado,
            p.fecha_creacion,
            p.fecha_modificacion,
            p.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            p.id_usuario_modificacion,
            umod.nombres AS nombre_usuario_modificacion
        FROM pro_producto p
        LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
        LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN pro_unidad_medida um ON p.id_unidad_medida = um.id
        LEFT JOIN gen_estacion e ON p.id_estacion = e.id
        LEFT JOIN gen_almacen a ON p.id_almacen_stock = a.id
        LEFT JOIN auth_usuario uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario umod ON p.id_usuario_modificacion = umod.id
        WHERE p.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
