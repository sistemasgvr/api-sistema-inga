CREATE OR REPLACE FUNCTION pro_crear_sub_categoria(
    p_id_categoria BIGINT,
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_orden INTEGER DEFAULT 0,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_codigo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := UPPER(TRIM(p_codigo));

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre de la subcategoría es obligatorio', 'registro', NULL);
    END IF;

    IF v_codigo IS NULL OR v_codigo = '' THEN
        RETURN json_build_object('error', 'El código de la subcategoría es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_subcategoria
        WHERE estado = 1
          AND id_categoria = p_id_categoria
          AND codigo = v_codigo
    ) THEN
        RETURN json_build_object('error', 'Ya existe una subcategoría activa con el código ' || v_codigo || ' en esta categoría', 'registro', NULL);
    END IF;

    INSERT INTO pro_subcategoria (
        id_categoria,
        codigo,
        nombre,
        orden,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_categoria,
        v_codigo,
        TRIM(p_nombre),
        p_orden,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_sub_categoria(v_id);
END;
$function$;