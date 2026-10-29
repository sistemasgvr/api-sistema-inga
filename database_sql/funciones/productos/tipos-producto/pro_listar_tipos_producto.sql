DROP FUNCTION IF EXISTS pro_listar_tipos_producto(BIGINT);
CREATE OR REPLACE FUNCTION pro_listar_tipos_producto(p_id_empresa BIGINT DEFAULT NULL) RETURNS JSON LANGUAGE sql STABLE AS $$
  SELECT COALESCE(json_agg(t ORDER BY t.nombre, t.id), '[]'::json)
  FROM (SELECT id, nombre, permite_venta, requiere_receta, requiere_estacion, permite_stock_inicial
    FROM pro_tipo_producto WHERE estado = 1
      AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa)) t;
$$;