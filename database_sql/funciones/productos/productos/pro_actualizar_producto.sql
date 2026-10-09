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
    v_tipo pro_tipo_producto%ROWTYPE;
    v_producto pro_producto%ROWTYPE;
    v_estacion BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El producto no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT * INTO v_producto FROM pro_producto WHERE id = p_id;
    SELECT * INTO v_tipo FROM pro_tipo_producto WHERE id = COALESCE(p_tipo_producto, v_producto.tipo_producto) AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Tipo de producto inexistente o inactivo', 'registro', NULL);
    END IF;
    v_estacion := CASE WHEN v_tipo.requiere_estacion THEN COALESCE(p_id_estacion, v_producto.id_estacion) ELSE NULL END;
    IF v_tipo.requiere_estacion AND v_estacion IS NULL THEN
        RETURN json_build_object('error', 'Debe asignar una estación para este tipo de producto', 'registro', NULL);
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

    SELECT COALESCE(p_controla_stock, controla_stock), COALESCE(p_id_almacen_stock, id_almacen_stock)
    INTO v_controla_stock, v_id_almacen
    FROM pro_producto WHERE id = p_id;

    IF v_controla_stock = TRUE AND v_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El producto controla stock pero no tiene un almacén asignado', 'registro', NULL);
    END IF;

    UPDATE pro_producto
    SET
        id_subcategoria = COALESCE(p_id_subcategoria, id_subcategoria),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        id_estacion = v_estacion,
        id_almacen_stock = CASE WHEN v_controla_stock THEN v_id_almacen ELSE NULL END,
        codigo_interno = COALESCE(v_codigo_interno, codigo_interno),
        nombre = COALESCE(v_nombre, nombre),
        descripcion = CASE WHEN p_descripcion = '' THEN NULL ELSE COALESCE(p_descripcion, descripcion) END,
        tipo_producto = COALESCE(p_tipo_producto, tipo_producto),
        precio_venta = CASE WHEN v_tipo.permite_venta THEN COALESCE(p_precio_venta, precio_venta) ELSE 0 END,
        afecto_igv = COALESCE(p_afecto_igv, afecto_igv),
        controla_stock = COALESCE(p_controla_stock, controla_stock),
        disponible_venta = v_tipo.permite_venta AND COALESCE(p_disponible_venta, disponible_venta),
        tiempo_prep_min = CASE WHEN v_tipo.requiere_receta THEN COALESCE(p_tiempo_prep_min, tiempo_prep_min) ELSE NULL END,
        imagen_url = CASE WHEN p_imagen_url = '' THEN NULL ELSE COALESCE(p_imagen_url, imagen_url) END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN pro_obtener_producto(p_id);
END;
$function$;