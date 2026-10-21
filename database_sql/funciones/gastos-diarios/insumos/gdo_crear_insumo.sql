-- Creo un insumo en la lista maestra. Solo exige nombre y categoría (se crea al vuelo desde
-- el registro rápido); la unidad se elige en cada compra.
DROP FUNCTION IF EXISTS gdo_crear_insumo(
    p_id_categoria BIGINT,
    p_nombre VARCHAR,
    p_precio_referencial NUMERIC,
    p_id_proveedor_habitual BIGINT,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gdo_crear_insumo(
    p_id_categoria BIGINT,
    p_nombre VARCHAR,
    p_precio_referencial NUMERIC DEFAULT 0,
    p_id_proveedor_habitual BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_nombre VARCHAR;
    v_existente RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre del insumo es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gdo_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF COALESCE(p_precio_referencial, 0) < 0 THEN
        RETURN json_build_object('error', 'El precio referencial no puede ser negativo', 'registro', NULL);
    END IF;

    -- Busco el duplicado para avisar si existe pero está de baja.
    SELECT id, estado INTO v_existente
    FROM gdo_insumo
    WHERE id_categoria = p_id_categoria AND LOWER(nombre) = LOWER(v_nombre);

    IF FOUND THEN
        IF v_existente.estado = 0 THEN
            RETURN json_build_object(
                'error', 'Ya existe "' || v_nombre || '" en esta categoría, pero está dado de baja. Reactívalo desde la lista de insumos.',
                'registro', NULL
            );
        END IF;
        RETURN json_build_object(
            'error', 'Ya existe "' || v_nombre || '" en esta categoría',
            'registro', NULL
        );
    END IF;

    IF p_id_proveedor_habitual IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_persona
        WHERE id = p_id_proveedor_habitual AND estado = 1 AND es_proveedor = TRUE
    ) THEN
        RETURN json_build_object(
            'error', 'El proveedor habitual debe ser una persona marcada como proveedor',
            'registro', NULL
        );
    END IF;

    INSERT INTO gdo_insumo (
        id_categoria, nombre, precio_referencial, id_proveedor_habitual,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_categoria, v_nombre, COALESCE(p_precio_referencial, 0),
        p_id_proveedor_habitual,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gdo_obtener_insumo(v_id);
END;
$function$;
