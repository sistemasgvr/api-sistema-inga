-- Actualizo un insumo de la lista maestra (NULL = sin cambio).
DROP FUNCTION IF EXISTS gdo_actualizar_insumo(
    p_id BIGINT,
    p_id_categoria BIGINT,
    p_nombre VARCHAR,
    p_precio_referencial NUMERIC,
    p_id_proveedor_habitual BIGINT,
    p_quitar_proveedor BOOLEAN,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION gdo_actualizar_insumo(
    p_id BIGINT,
    p_id_categoria BIGINT DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_precio_referencial NUMERIC DEFAULT NULL,
    p_id_proveedor_habitual BIGINT DEFAULT NULL,
    p_quitar_proveedor BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
    v_empresa BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_empresa := COALESCE(p_id_empresa, (SELECT id_empresa FROM gdo_insumo WHERE id = p_id));

    IF p_nombre IS NOT NULL THEN
        v_nombre := NULLIF(TRIM(p_nombre), '');
        IF v_nombre IS NULL THEN
            RETURN json_build_object('error', 'El nombre del insumo es obligatorio', 'registro', NULL);
        END IF;
    END IF;

    IF p_id_categoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gdo_categoria WHERE id = p_id_categoria AND estado = 1
          AND (v_empresa IS NULL OR id_empresa = v_empresa)
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_precio_referencial IS NOT NULL AND p_precio_referencial < 0 THEN
        RETURN json_build_object('error', 'El precio referencial no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_proveedor_habitual IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_persona
        WHERE id = p_id_proveedor_habitual AND estado = 1 AND es_proveedor = TRUE
          AND (v_empresa IS NULL OR id_empresa = v_empresa)
    ) THEN
        RETURN json_build_object('error', 'El proveedor habitual debe ser una persona marcada como proveedor', 'registro', NULL);
    END IF;

    UPDATE gdo_insumo
    SET
        id_categoria = COALESCE(p_id_categoria, id_categoria),
        nombre = COALESCE(v_nombre, nombre),
        precio_referencial = COALESCE(p_precio_referencial, precio_referencial),
        id_proveedor_habitual = CASE
            WHEN p_quitar_proveedor THEN NULL
            WHEN p_id_proveedor_habitual IS NOT NULL THEN p_id_proveedor_habitual
            ELSE id_proveedor_habitual
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El insumo no existe o está inactivo', 'registro', NULL);
    END IF;

    RETURN gdo_obtener_insumo(p_id, v_empresa);
END;
$function$;