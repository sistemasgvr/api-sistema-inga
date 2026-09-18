-- Creo una categoría (o subcategoría) de gasto administrativo.
--
-- Dos reglas que impongo acá:
--
-- 1. Solo un nivel de anidación. Si el padre indicado ya es hijo de otro, lo
--    rechazo. Sin esto, alguien podría armar un árbol de cinco niveles que ni
--    el formulario ni el reporte saben mostrar.
--
-- 2. La subcategoría hereda el tipo del padre. No tiene sentido que "Luz" sea
--    variable si cuelga de "Servicios básicos", que es fijo: el reporte suma
--    por tipo y quedaría contradictorio.
CREATE OR REPLACE FUNCTION gad_crear_categoria(
    p_codigo VARCHAR,
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
    v_codigo VARCHAR;
    v_nombre VARCHAR;
    v_padre RECORD;
    v_tipo SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := UPPER(NULLIF(TRIM(p_codigo), ''));
    v_nombre := NULLIF(TRIM(p_nombre), '');
    v_tipo := COALESCE(p_tipo_gasto, 1);

    IF v_codigo IS NULL THEN
        RETURN json_build_object('error', 'El código de la categoría es obligatorio', 'registro', NULL);
    END IF;

    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre de la categoría es obligatorio', 'registro', NULL);
    END IF;

    IF v_tipo NOT IN (1, 2) THEN
        RETURN json_build_object('error', 'El tipo de gasto debe ser fijo o variable', 'registro', NULL);
    END IF;

    -- Comparo contra todas, activas e inactivas, porque el UNIQUE tampoco
    -- distingue estado. Si mirara solo las activas, el INSERT reventaría con
    -- un error crudo de Postgres en vez de este mensaje.
    IF EXISTS (SELECT 1 FROM gad_categoria WHERE codigo = v_codigo) THEN
        RETURN json_build_object(
            'error', 'Ya existe una categoría con el código ' || v_codigo,
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

        -- Hereda el tipo del padre, ignorando lo que haya llegado.
        v_tipo := v_padre.tipo_gasto;
    END IF;

    INSERT INTO gad_categoria (
        id_categoria_padre, codigo, nombre, tipo_gasto, orden,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_categoria_padre, v_codigo, v_nombre, v_tipo, COALESCE(p_orden, 0),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gad_obtener_categoria(v_id);
END;
$function$;
