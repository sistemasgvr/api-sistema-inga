CREATE OR REPLACE FUNCTION pro_actualizar_categoria(
    p_id BIGINT,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_es_carta BOOLEAN DEFAULT NULL,
    p_orden INTEGER DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo VARCHAR;
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := NULLIF(TRIM(p_codigo), '');
    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_categoria
        WHERE LOWER(TRIM(codigo)) = LOWER(v_codigo)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otra categoría con el código ' || v_codigo, 'registro', NULL);
    END IF;

    UPDATE pro_categoria
    SET
        codigo = COALESCE(UPPER(v_codigo), codigo),
        nombre = COALESCE(v_nombre, nombre),
        descripcion = CASE 
            WHEN p_descripcion IS NULL THEN descripcion 
            ELSE NULLIF(TRIM(p_descripcion), '') 
        END,
        es_carta = COALESCE(p_es_carta, es_carta),
        orden = COALESCE(p_orden, orden),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Categoría no encontrada o inactiva', 'registro', NULL);
    END IF;

    RETURN pro_obtener_categoria(p_id);
END;
$function$;