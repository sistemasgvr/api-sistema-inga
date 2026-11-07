-- Conteos de productos activos de un tipo, para avisar antes de cambiar sus indicadores.
DROP FUNCTION IF EXISTS pro_impacto_tipo_producto(p_id BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION pro_impacto_tipo_producto(
  p_id BIGINT, p_id_empresa BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql STABLE AS $$
DECLARE v_impacto JSON;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pro_tipo_producto
    WHERE id = p_id AND estado = 1
      AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa)
  ) THEN
    RETURN json_build_object('error', 'Tipo de producto no encontrado', 'registro', NULL);
  END IF;
  SELECT json_build_object(
    'total', COUNT(*),
    'sin_receta', COUNT(*) FILTER (WHERE pro_receta_vigente(p.id) IS NULL),
    'sin_estacion', COUNT(*) FILTER (WHERE p.id_estacion IS NULL),
    'en_venta', COUNT(*) FILTER (WHERE p.disponible_venta)
  ) INTO v_impacto
  FROM pro_producto p
  WHERE p.tipo_producto = p_id AND p.estado = 1
    AND (p_id_empresa IS NULL OR p.id_empresa = p_id_empresa);
  RETURN json_build_object('registro', v_impacto);
END $$;
