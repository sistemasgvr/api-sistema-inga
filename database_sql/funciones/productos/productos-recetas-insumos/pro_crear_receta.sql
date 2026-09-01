CREATE OR REPLACE FUNCTION pro_crear_receta(
    p_id_producto BIGINT,
    p_nombre VARCHAR DEFAULT NULL,
    p_rendimiento_porciones NUMERIC DEFAULT 1,
    p_observacion TEXT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_siguiente_version INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
        RETURN json_build_object('error', 'El producto asociado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_rendimiento_porciones <= 0 THEN
        RETURN json_build_object('error', 'El rendimiento en porciones debe ser mayor a cero', 'registro', NULL);
    END IF;

    SELECT COALESCE(MAX(version), 0) + 1 INTO v_siguiente_version
    FROM pro_receta
    WHERE id_producto = p_id_producto;

    UPDATE pro_receta
    SET vigente = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_producto = p_id_producto AND vigente = TRUE;

    INSERT INTO pro_receta (
        id_producto,
        version,
        nombre,
        rendimiento_porciones,
        vigente,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_producto,
        v_siguiente_version,
        NULLIF(TRIM(p_nombre), ''),
        p_rendimiento_porciones,
        TRUE,
        p_observacion,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_receta(v_id);
END;
$function$;