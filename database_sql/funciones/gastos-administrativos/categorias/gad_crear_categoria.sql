-- Creo una categoría o subcategoría de gasto. Solo un nivel de anidación y la subcategoría
-- hereda el tipo del padre.
DROP FUNCTION IF EXISTS gad_crear_categoria(
    p_nombre VARCHAR,
    p_tipo_gasto SMALLINT,
    p_id_categoria_padre BIGINT,
    p_orden INTEGER,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gad_crear_categoria(
    p_nombre VARCHAR,
    p_tipo_gasto SMALLINT DEFAULT 1,
    p_id_categoria_padre BIGINT DEFAULT NULL,
    p_orden INTEGER DEFAULT 0,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_nombre VARCHAR;
    v_padre RECORD;
    v_tipo SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');
    v_tipo := COALESCE(p_tipo_gasto, 1);

    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre de la categoría es obligatorio', 'registro', NULL);
    END IF;

    IF v_tipo NOT IN (1, 2) THEN
        RETURN json_build_object('error', 'El tipo de gasto debe ser fijo o variable', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM gad_categoria
        WHERE estado = 1
          AND id_categoria_padre IS NOT DISTINCT FROM p_id_categoria_padre
          AND LOWER(nombre) = LOWER(v_nombre)
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe una categoría con el nombre ' || v_nombre,
            'registro', NULL
        );
    END IF;

    IF p_id_categoria_padre IS NOT NULL THEN
        SELECT id, id_categoria_padre, tipo_gasto, nombre
        INTO v_padre
        FROM gad_categoria
        WHERE id = p_id_categoria_padre AND estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object(
                'error', 'La categoría padre indicada no existe o está inactiva',
                'registro', NULL
            );
        END IF;

        IF v_padre.id_categoria_padre IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'No se puede anidar bajo "' || v_padre.nombre ||
                         '" porque ya es una subcategoría. Solo se admite un nivel.',
                'registro', NULL
            );
        END IF;

        v_tipo := v_padre.tipo_gasto;
    END IF;

    INSERT INTO gad_categoria (
        id_categoria_padre, nombre, tipo_gasto, orden,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_categoria_padre, v_nombre, v_tipo, COALESCE(p_orden, 0),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gad_obtener_categoria(v_id);
END;
$function$;
