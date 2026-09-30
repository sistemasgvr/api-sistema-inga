CREATE OR REPLACE FUNCTION public.alm_listar_kardex(
  p_producto BIGINT DEFAULT NULL,
  p_almacen BIGINT DEFAULT NULL,
  p_limite INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registros', COALESCE(json_agg(k ORDER BY k.fecha_confirmacion DESC,k.id DESC), '[]'::JSON))
  FROM (
    SELECT * FROM vw_alm_kardex
    WHERE (p_producto IS NULL OR id_producto=p_producto)
      AND (p_almacen IS NULL OR id_almacen=p_almacen)
    ORDER BY fecha_confirmacion DESC,id DESC
    LIMIT LEAST(GREATEST(p_limite,1),200) OFFSET GREATEST(p_offset,0)
  ) k;
$$;
