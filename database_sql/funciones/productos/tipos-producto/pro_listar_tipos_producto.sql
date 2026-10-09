CREATE OR REPLACE FUNCTION pro_listar_tipos_producto() RETURNS JSON LANGUAGE sql STABLE AS $$
  SELECT COALESCE(json_agg(t ORDER BY t.nombre, t.id), '[]'::json)
  FROM (SELECT id, nombre, permite_venta, requiere_receta, requiere_estacion, permite_stock_inicial
    FROM pro_tipo_producto WHERE estado = 1) t;
$$;
