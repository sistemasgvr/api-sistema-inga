-- Actualizo un insumo de la lista maestra. Lo que llega en NULL se queda igual.
CREATE OR REPLACE FUNCTION gdo_actualizar_insumo(
    p_id BIGINT,
    p_id_categoria BIGINT DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_precio_referencial NUMERIC DEFAULT NULL,
    p_id_proveedor_habitual BIGINT DEFAULT NULL,
    p_quitar_proveedor BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_actual RECORD;
    v_nombre VARCHAR;
    v_categoria BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    SELECT id_categoria, nombre INTO v_actual
    FROM gdo_insumo WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El insumo no existe o está inactivo', 'registro', NULL);
    END IF;

    v_categoria := COALESCE(p_id_categoria, v_actual.id_categoria);

    IF p_id_categoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gdo_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    -- Valido el duplicado contra la categoría FINAL, no la actual: si se está
    -- moviendo de categoría, el choque puede aparecer en la de destino.
    IF EXISTS (
        SELECT 1 FROM gdo_insumo
        WHERE id_categoria = v_categoria
          AND LOWER(nombre) = LOWER(COALESCE(v_nombre, v_actual.nombre))
          AND id <> p_id
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe otro insumo con ese nombre en la categoría de destino',
            'registro', NULL
        );
    END IF;

    IF p_precio_referencial IS NOT NULL AND p_precio_referencial < 0 THEN
        RETURN json_build_object('error', 'El precio referencial no puede ser negativo', 'registro', NULL);
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

    UPDATE gdo_insumo
    SET
        id_categoria = v_categoria,
        nombre = COALESCE(v_nombre, nombre),
        precio_referencial = COALESCE(p_precio_referencial, precio_referencial),
        -- La bandera permite desasignar el proveedor: mandar NULL significa
        -- "no lo estoy cambiando", no "quítalo".
        id_proveedor_habitual = CASE
            WHEN p_quitar_proveedor THEN NULL
            ELSE COALESCE(p_id_proveedor_habitual, id_proveedor_habitual)
        END,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN gdo_obtener_insumo(p_id);
END;
$function$;
