CREATE OR REPLACE FUNCTION public.alm_listar_stock(
  p_producto BIGINT DEFAULT NULL,
  p_almacen BIGINT DEFAULT NULL,
  p_limite INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registros', COALESCE(json_agg(s ORDER BY s.id), '[]'::JSON))
  FROM (
    SELECT * FROM alm_producto_stock
    WHERE (p_producto IS NULL OR id_producto=p_producto)
      AND (p_almacen IS NULL OR id_almacen=p_almacen)
    ORDER BY id
    LIMIT LEAST(GREATEST(p_limite,1),200) OFFSET GREATEST(p_offset,0)
  ) s;
$$;
