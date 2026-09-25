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

CREATE OR REPLACE FUNCTION pro_actualizar_producto(
    p_id BIGINT,
    p_id_subcategoria BIGINT DEFAULT NULL,
    p_id_unidad_medida BIGINT DEFAULT NULL,
    p_id_estacion BIGINT DEFAULT NULL,
    p_id_almacen_stock BIGINT DEFAULT NULL,
    p_codigo_interno VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion TEXT DEFAULT NULL,
    p_tipo_producto SMALLINT DEFAULT NULL,
    p_precio_venta NUMERIC DEFAULT NULL,
    p_afecto_igv BOOLEAN DEFAULT NULL,
    p_controla_stock BOOLEAN DEFAULT NULL,
    p_disponible_venta BOOLEAN DEFAULT NULL,
    p_tiempo_prep_min INTEGER DEFAULT NULL,
    p_imagen_url VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo_interno VARCHAR;
    v_nombre VARCHAR;
    v_controla_stock BOOLEAN;
    v_id_almacen BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El producto no existe o está inactivo', 'registro', NULL);
    END IF;

    v_codigo_interno := NULLIF(TRIM(p_codigo_interno), '');
    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_codigo_interno IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_producto
        WHERE LOWER(TRIM(codigo_interno)) = LOWER(v_codigo_interno)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro producto con el código ' || v_codigo_interno, 'registro', NULL);
    END IF;

    IF p_id_subcategoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_subcategoria WHERE id = p_id_subcategoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La subcategoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_unidad_medida IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_unidad_medida WHERE id = p_id_unidad_medida AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La unidad de medida indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_estacion IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_estacion WHERE id = p_id_estacion AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La estación de impresión indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_almacen_stock IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_stock AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén de stock indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_controla_stock := COALESCE(p_controla_stock, (SELECT controla_stock FROM pro_producto WHERE id = p_id));
    v_id_almacen := CASE WHEN p_id_almacen_stock IS NOT NULL THEN p_id_almacen_stock ELSE (SELECT id_almacen_stock FROM pro_producto WHERE id = p_id) END;

    IF v_controla_stock = TRUE AND v_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El producto controla stock pero no tiene un almacén asignado', 'registro', NULL);
    END IF;

    UPDATE pro_producto
    SET
        id_subcategoria = COALESCE(p_id_subcategoria, id_subcategoria),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        id_estacion = p_id_estacion,
        id_almacen_stock = p_id_almacen_stock,
        codigo_interno = COALESCE(v_codigo_interno, codigo_interno),
        nombre = COALESCE(v_nombre, nombre),
        descripcion = p_descripcion,
        tipo_producto = COALESCE(p_tipo_producto, tipo_producto),
        precio_venta = COALESCE(p_precio_venta, precio_venta),
        afecto_igv = COALESCE(p_afecto_igv, afecto_igv),
        controla_stock = COALESCE(p_controla_stock, controla_stock),
        disponible_venta = COALESCE(p_disponible_venta, disponible_venta),
        tiempo_prep_min = p_tiempo_prep_min,
        imagen_url = p_imagen_url,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN pro_obtener_producto(p_id);
END;
$function$;