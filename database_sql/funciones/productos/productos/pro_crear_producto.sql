CREATE OR REPLACE FUNCTION pro_crear_producto(
    p_id_subcategoria BIGINT,
    p_id_unidad_medida BIGINT,
    p_codigo_interno VARCHAR,
    p_nombre VARCHAR,
    p_tipo_producto SMALLINT,
    p_id_estacion BIGINT DEFAULT NULL,
    p_id_almacen_stock BIGINT DEFAULT NULL,
    p_descripcion TEXT DEFAULT NULL,
    p_precio_venta NUMERIC DEFAULT 0,
    p_afecto_igv BOOLEAN DEFAULT TRUE,
    p_controla_stock BOOLEAN DEFAULT FALSE,
    p_disponible_venta BOOLEAN DEFAULT TRUE,
    p_tiempo_prep_min INTEGER DEFAULT NULL,
    p_imagen_url VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_codigo_interno VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo_interno := NULLIF(TRIM(p_codigo_interno), '');
    IF v_codigo_interno IS NULL THEN
        RETURN json_build_object('error', 'El código interno del producto es obligatorio', 'registro', NULL);
    END IF;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre del producto es obligatorio', 'registro', NULL);
    END IF;

    IF p_tipo_producto IS NULL THEN
        RETURN json_build_object('error', 'El tipo de producto es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_producto
        WHERE LOWER(TRIM(codigo_interno)) = LOWER(v_codigo_interno)
    ) THEN
        RETURN json_build_object('error', 'Ya existe un producto con el código ' || v_codigo_interno, 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_subcategoria WHERE id = p_id_subcategoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La subcategoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
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

    IF p_tipo_producto IN (3, 4, 5, 6) AND p_id_estacion IS NULL THEN
        RETURN json_build_object('error', 'Debe asignar una estación de impresión para platos, tragos o bebidas', 'registro', NULL);
    END IF;

    IF p_controla_stock = TRUE AND p_id_almacen_stock IS NULL THEN
        RETURN json_build_object('error', 'Debe seleccionar un almacén si el producto controla stock directamente', 'registro', NULL);
    END IF;

    INSERT INTO pro_producto (
        id_subcategoria,
        id_unidad_medida,
        id_estacion,
        id_almacen_stock,
        codigo_interno,
        nombre,
        descripcion,
        tipo_producto,
        precio_venta,
        afecto_igv,
        controla_stock,
        disponible_venta,
        tiempo_prep_min,
        imagen_url,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_subcategoria,
        p_id_unidad_medida,
        p_id_estacion,
        p_id_almacen_stock,
        v_codigo_interno,
        TRIM(p_nombre),
        p_descripcion,
        p_tipo_producto,
        COALESCE(p_precio_venta, 0),
        COALESCE(p_afecto_igv, TRUE),
        COALESCE(p_controla_stock, FALSE),
        COALESCE(p_disponible_venta, TRUE),
        p_tiempo_prep_min,
        p_imagen_url,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- INICIALIZACIÓN DE STOCK (Solo si controla_stock = TRUE y tiene almacén)
    IF COALESCE(p_controla_stock, FALSE) = TRUE AND p_id_almacen_stock IS NOT NULL THEN
        INSERT INTO alm_producto_stock (
            id_almacen,
            id_producto,
            stock_actual,
            stock_minimo,
            stock_reservado,
            costo_promedio,
            id_usuario_creacion,
            id_usuario_modificacion
        )
        VALUES (
            p_id_almacen_stock,
            v_id,
            0,
            0,
            0,
            0,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        )
        ON CONFLICT (id_almacen, id_producto) DO NOTHING;
    END IF;

    RETURN pro_obtener_producto(v_id);
END;
$function$;