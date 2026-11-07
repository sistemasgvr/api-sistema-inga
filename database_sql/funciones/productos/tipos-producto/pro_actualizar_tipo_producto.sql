-- Cambia los cuatro indicadores de un tipo. No toca los productos existentes:
-- el aviso de productos afectados se obtiene con pro_impacto_tipo_producto.
DROP FUNCTION IF EXISTS pro_actualizar_tipo_producto(
    p_id BIGINT,
    p_permite_venta BOOLEAN,
    p_requiere_receta BOOLEAN,
    p_requiere_estacion BOOLEAN,
    p_permite_stock_inicial BOOLEAN,
    p_usuario BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pro_actualizar_tipo_producto(
  p_id BIGINT, p_permite_venta BOOLEAN, p_requiere_receta BOOLEAN,
  p_requiere_estacion BOOLEAN, p_permite_stock_inicial BOOLEAN, p_usuario BIGINT DEFAULT NULL,
  p_id_empresa BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_tipo pro_tipo_producto%ROWTYPE;
  v_empresa BIGINT;
BEGIN
  v_empresa := COALESCE(p_id_empresa, (SELECT t.id_empresa FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador WHERE u.id = p_usuario));
  IF p_permite_venta IS NULL OR p_requiere_receta IS NULL OR p_requiere_estacion IS NULL OR p_permite_stock_inicial IS NULL THEN
    RETURN json_build_object('error', 'Los cuatro indicadores son obligatorios', 'registro', NULL);
  END IF;
  UPDATE pro_tipo_producto
  SET permite_venta = p_permite_venta,
      requiere_receta = p_requiere_receta,
      requiere_estacion = p_requiere_estacion,
      permite_stock_inicial = p_permite_stock_inicial AND NOT p_requiere_receta,
      id_usuario_modificacion = p_usuario,
      fecha_modificacion = CURRENT_TIMESTAMP
  WHERE id = p_id AND estado = 1
    AND (v_empresa IS NULL OR id_empresa = v_empresa)
  RETURNING * INTO v_tipo;
  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Tipo de producto no encontrado', 'registro', NULL);
  END IF;
  RETURN json_build_object('registro', to_json(v_tipo));
END $$;
