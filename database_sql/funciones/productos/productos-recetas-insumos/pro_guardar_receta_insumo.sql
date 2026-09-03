CREATE OR REPLACE FUNCTION pro_guardar_receta_insumo(
    p_id_receta BIGINT,
    p_id_producto_insumo BIGINT,
    p_cantidad NUMERIC,
    p_id_unidad_medida BIGINT,
    p_porcentaje_merma NUMERIC DEFAULT 0,
    p_es_opcional BOOLEAN DEFAULT FALSE,
    p_grupo_sustitucion INTEGER DEFAULT NULL,
    p_orden INTEGER DEFAULT 0,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_insumo_tabla BIGINT;
    v_tipo_insumo SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM pro_receta WHERE id = p_id_receta AND estado = 1) THEN
        RETURN json_build_object('error', 'La receta indicada no existe', 'registro', NULL);
    END IF;

    SELECT tipo_producto INTO v_tipo_insumo
    FROM pro_producto
    WHERE id = p_id_producto_insumo AND estado = 1;

    IF v_tipo_insumo IS NULL THEN
        RETURN json_build_object('error', 'El producto insumo seleccionado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad del insumo debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pro_unidad_medida WHERE id = p_id_unidad_medida AND estado = 1) THEN
        RETURN json_build_object('error', 'La unidad de medida seleccionada no es válida', 'registro', NULL);
    END IF;

    INSERT INTO pro_receta_insumo (
        id_receta,
        id_producto_insumo,
        cantidad,
        id_unidad_medida,
        porcentaje_merma,
        es_opcional,
        grupo_sustitucion,
        orden,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_receta,
        p_id_producto_insumo,
        p_cantidad,
        p_id_unidad_medida,
        COALESCE(p_porcentaje_merma, 0),
        COALESCE(p_es_opcional, FALSE),
        p_grupo_sustitucion,
        COALESCE(p_orden, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_insumo_tabla;

    RETURN pro_obtener_receta(p_id_receta);
END;
$function$;