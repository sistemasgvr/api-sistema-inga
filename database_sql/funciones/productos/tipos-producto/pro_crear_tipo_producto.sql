CREATE OR REPLACE FUNCTION pro_crear_tipo_producto(
  p_nombre VARCHAR, p_permite_venta BOOLEAN, p_requiere_receta BOOLEAN,
  p_requiere_estacion BOOLEAN, p_permite_stock_inicial BOOLEAN, p_usuario BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_tipo pro_tipo_producto%ROWTYPE;
BEGIN
  IF NULLIF(trim(p_nombre), '') IS NULL THEN
    RETURN json_build_object('error', 'El nombre es obligatorio', 'registro', NULL);
  END IF;
  IF p_permite_venta IS NULL OR p_requiere_receta IS NULL OR p_requiere_estacion IS NULL OR p_permite_stock_inicial IS NULL THEN
    RETURN json_build_object('error', 'Los cuatro indicadores son obligatorios', 'registro', NULL);
  END IF;
  INSERT INTO pro_tipo_producto(nombre, permite_venta, requiere_receta, requiere_estacion,
    permite_stock_inicial, id_usuario_creacion, id_usuario_modificacion)
  VALUES(trim(p_nombre), p_permite_venta, p_requiere_receta, p_requiere_estacion,
    p_permite_stock_inicial, p_usuario, p_usuario) RETURNING * INTO v_tipo;
  RETURN json_build_object('registro', to_json(v_tipo));
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('error', 'Ya existe un tipo de producto con ese nombre', 'registro', NULL);
END $$;
