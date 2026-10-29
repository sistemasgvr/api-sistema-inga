DROP FUNCTION IF EXISTS pro_actualizar_adicional(
    p_id BIGINT,
    p_nombre VARCHAR,
    p_precio_adicional NUMERIC,
    p_id_producto_insumo BIGINT,
    p_cantidad_insumo NUMERIC,
    p_id_unidad_medida BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pro_actualizar_adicional(
    p_id BIGINT,
    p_nombre VARCHAR DEFAULT NULL,
    p_precio_adicional NUMERIC DEFAULT NULL,
    p_id_producto_insumo BIGINT DEFAULT NULL,
    p_cantidad_insumo NUMERIC DEFAULT NULL,
    p_id_unidad_medida BIGINT DEFAULT NULL,
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

    v_empresa := COALESCE(p_id_empresa, (SELECT a.id_empresa FROM pro_adicional a WHERE a.id = p_id));

    IF NOT EXISTS (SELECT 1 FROM pro_adicional WHERE id = p_id AND estado = 1 AND (v_empresa IS NULL OR id_empresa = v_empresa)) THEN
        RETURN json_build_object('error', 'El adicional no existe o está inactivo', 'registro', NULL);
    END IF;

    v_nombre := NULLIF(TRIM(p_nombre), '');

    UPDATE pro_adicional
    SET
        nombre = COALESCE(v_nombre, nombre),
        precio_adicional = COALESCE(p_precio_adicional, precio_adicional),
        id_producto_insumo = p_id_producto_insumo,
        cantidad_insumo = COALESCE(p_cantidad_insumo, cantidad_insumo),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    RETURN pro_obtener_adicional(p_id, v_empresa);
END;
$function$;