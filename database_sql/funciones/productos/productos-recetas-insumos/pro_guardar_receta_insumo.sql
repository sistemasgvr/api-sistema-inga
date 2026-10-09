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
    v_id_producto_receta BIGINT;
    v_ciclo TEXT;
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

    SELECT id_producto INTO v_id_producto_receta
    FROM pro_receta
    WHERE id = p_id_receta AND estado = 1;

    -- Un producto no puede ser insumo de sí mismo.
    IF p_id_producto_insumo = v_id_producto_receta THEN
        RETURN json_build_object(
            'error', 'Un producto no puede ser insumo de su propia receta',
            'registro', NULL
        );
    END IF;

    -- Una receta puede contener platos que tienen su propia receta. Eso está
    -- permitido, pero abre la puerta a ciclos: si A contiene B y B contiene A,
    -- el cálculo de costo y la producción entrarían en recursión infinita.
    -- Se sube por los ancestros del insumo propuesto y se rechaza si aparece el
    -- producto cuya receta se está editando.
    WITH RECURSIVE ancestros(id, nombre, nivel) AS (
        SELECT ri.id_producto_insumo, pa.nombre, 1
        FROM pro_receta_insumo ri
        JOIN pro_producto pa ON pa.id = ri.id_producto_insumo
        WHERE ri.estado = 1
          AND ri.id_receta = (
              SELECT r2.id FROM pro_receta r2
              WHERE r2.id_producto = p_id_producto_insumo
                AND r2.estado = 1 AND r2.vigente
              ORDER BY r2.version DESC LIMIT 1
          )
        UNION ALL
        SELECT ri.id_producto_insumo, pa.nombre, a.nivel + 1
        FROM ancestros a
        JOIN pro_receta r3 ON r3.id_producto = a.id AND r3.estado = 1 AND r3.vigente
        JOIN pro_receta_insumo ri ON ri.id_receta = r3.id AND ri.estado = 1
        JOIN pro_producto pa ON pa.id = ri.id_producto_insumo
        WHERE a.nivel < 20
    )
    SELECT string_agg(format('%s (nivel %s)', a.nombre, a.nivel), ' -> ' ORDER BY a.nivel)
    INTO v_ciclo
    FROM ancestros a
    WHERE a.id = v_id_producto_receta;

    IF v_ciclo IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'No se puede agregar: se generaría un ciclo de recetas. ' || v_ciclo,
            'registro', NULL
        );
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