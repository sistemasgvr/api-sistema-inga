CREATE OR REPLACE FUNCTION pro_crear_adicional(
    p_id_producto BIGINT,
    p_nombre VARCHAR,
    p_precio_adicional NUMERIC DEFAULT 0,
    p_id_producto_insumo BIGINT DEFAULT NULL,
    p_cantidad_insumo NUMERIC DEFAULT 0,
    p_id_unidad_medida BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
        RETURN json_build_object('error', 'El producto principal no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre del adicional es obligatorio', 'registro', NULL);
    END IF;

    IF p_precio_adicional < 0 THEN
        RETURN json_build_object('error', 'El precio adicional no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_producto_insumo IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto_insumo AND estado = 1) THEN
            RETURN json_build_object('error', 'El insumo asociado al adicional no existe', 'registro', NULL);
        END IF;
        IF p_cantidad_insumo <= 0 OR p_id_unidad_medida IS NULL THEN
            RETURN json_build_object('error', 'Debe especificar la cantidad y la unidad de medida del insumo extra', 'registro', NULL);
        END IF;
    END IF;

    INSERT INTO pro_adicional (
        id_producto,
        nombre,
        precio_adicional,
        id_producto_insumo,
        cantidad_insumo,
        id_unidad_medida,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_producto,
        TRIM(p_nombre),
        COALESCE(p_precio_adicional, 0),
        p_id_producto_insumo,
        COALESCE(p_cantidad_insumo, 0),
        p_id_unidad_medida,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_adicional(v_id);
END;
$function$;