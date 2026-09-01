CREATE OR REPLACE FUNCTION pro_actualizar_sub_categoria(
    p_id BIGINT,
    p_id_categoria BIGINT DEFAULT NULL,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_orden INTEGER DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
    v_codigo VARCHAR;
    v_id_categoria BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');
    v_codigo := UPPER(NULLIF(TRIM(p_codigo), ''));

    SELECT COALESCE(p_id_categoria, id_categoria) INTO v_id_categoria
    FROM pro_subcategoria
    WHERE id = p_id AND estado = 1;

    IF v_id_categoria IS NULL THEN
        RETURN json_build_object('error', 'La subcategoría no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_categoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_subcategoria
        WHERE estado = 1
          AND id_categoria = v_id_categoria
          AND codigo = v_codigo
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otra subcategoría activa con el código ' || v_codigo || ' en esta categoría', 'registro', NULL);
    END IF;

    UPDATE pro_subcategoria
    SET
        id_categoria = COALESCE(p_id_categoria, id_categoria),
        codigo = COALESCE(v_codigo, codigo),
        nombre = COALESCE(v_nombre, nombre),
        orden = COALESCE(p_orden, orden),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN pro_obtener_sub_categoria(p_id);
END;
$function$;