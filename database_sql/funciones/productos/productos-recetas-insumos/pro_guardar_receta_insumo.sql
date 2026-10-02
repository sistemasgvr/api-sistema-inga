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
    v_id_usuario_final BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_id_usuario_final := p_id_usuario_auditoria;
    IF v_id_usuario_final IS NULL THEN
        SELECT id_usuario_creacion INTO v_id_usuario_final
        FROM pro_receta
        WHERE id = p_id_receta;
    END IF;

    IF v_id_usuario_final IS NULL THEN
        SELECT id INTO v_id_usuario_final
        FROM auth_usuario
        ORDER BY id ASC
        LIMIT 1;
    END IF;

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

    IF EXISTS (
        SELECT 1 
        FROM pro_receta_insumo 
        WHERE id_receta = p_id_receta 
          AND id_producto_insumo = p_id_producto_insumo 
          AND estado = 1
    ) THEN
        UPDATE pro_receta_insumo
        SET cantidad = p_cantidad,
            id_unidad_medida = p_id_unidad_medida,
            porcentaje_merma = COALESCE(p_porcentaje_merma, 0),
            es_opcional = COALESCE(p_es_opcional, FALSE),
            grupo_sustitucion = p_grupo_sustitucion,
            orden = COALESCE(p_orden, 0),
            id_usuario_modificacion = v_id_usuario_final,
            fecha_modificacion = NOW()
        WHERE id_receta = p_id_receta 
          AND id_producto_insumo = p_id_producto_insumo 
          AND estado = 1;
    ELSE
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
            v_id_usuario_final,
            v_id_usuario_final
        );
    END IF;

    PERFORM pro_recalcular_costo_receta(p_id_receta);

    RETURN pro_obtener_receta(p_id_receta);
END;
$function$;