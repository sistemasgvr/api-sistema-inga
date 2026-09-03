CREATE OR REPLACE FUNCTION pro_crear_categoria(
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
    p_es_carta BOOLEAN DEFAULT FALSE,
    p_orden INTEGER DEFAULT 0,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_codigo IS NULL OR TRIM(p_codigo) = '' THEN
        RETURN json_build_object('error', 'El código de la categoría es obligatorio', 'registro', NULL);
    END IF;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre de la categoría es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_categoria
        WHERE LOWER(TRIM(codigo)) = LOWER(TRIM(p_codigo))
    ) THEN
        RETURN json_build_object('error', 'Ya existe una categoría con el código ' || TRIM(p_codigo), 'registro', NULL);
    END IF;

    INSERT INTO pro_categoria (
        codigo,
        nombre,
        descripcion,
        es_carta,
        orden,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        UPPER(TRIM(p_codigo)),
        TRIM(p_nombre),
        NULLIF(TRIM(p_descripcion), ''),
        COALESCE(p_es_carta, FALSE),
        COALESCE(p_orden, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_categoria(v_id);
END;
$function$;