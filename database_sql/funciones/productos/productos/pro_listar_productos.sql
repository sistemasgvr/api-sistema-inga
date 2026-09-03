CREATE OR REPLACE FUNCTION pro_listar_productos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_tipo_producto SMALLINT DEFAULT NULL,
    p_id_subcategoria BIGINT DEFAULT NULL,
    p_id_categoria BIGINT DEFAULT NULL,
    p_estado INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_cant_total BIGINT;
    v_cant_activos BIGINT;
    v_cant_inactivos BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE p.estado = 1),
        COUNT(*) FILTER (WHERE p.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM pro_producto p
    LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
    LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
    WHERE (p_tipo_producto IS NULL OR p.tipo_producto = p_tipo_producto)
      AND (p_id_subcategoria IS NULL OR p.id_subcategoria = p_id_subcategoria)
      AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
      AND (
          p_busqueda = ''
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COUNT(*) INTO v_total
    FROM pro_producto p
    LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
    LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
    WHERE (p_estado IS NULL OR p.estado = p_estado)
      AND (p_tipo_producto IS NULL OR p.tipo_producto = p_tipo_producto)
      AND (p_id_subcategoria IS NULL OR p.id_subcategoria = p_id_subcategoria)
      AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
      AND (
          p_busqueda = ''
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
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
            p.tipo_producto,
            p.precio_venta,
            p.costo_receta_calculado,
            p.controla_stock,
            p.disponible_venta,
            p.estado,
            p.fecha_creacion,
            p.fecha_modificacion
        FROM pro_producto p
        LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
        LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN pro_unidad_medida um ON p.id_unidad_medida = um.id
        LEFT JOIN gen_estacion e ON p.id_estacion = e.id
        LEFT JOIN gen_almacen a ON p.id_almacen_stock = a.id
        WHERE (p_estado IS NULL OR p.estado = p_estado)
          AND (p_tipo_producto IS NULL OR p.tipo_producto = p_tipo_producto)
          AND (p_id_subcategoria IS NULL OR p.id_subcategoria = p_id_subcategoria)
          AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
          AND (
              p_busqueda = ''
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY p.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total', v_cant_total,
            'activos', v_cant_activos,
            'inactivos', v_cant_inactivos
        )
    );
END;
$function$;