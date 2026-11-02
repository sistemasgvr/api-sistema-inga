DROP FUNCTION IF EXISTS public.alm_listar_kardex(
    p_producto BIGINT,
    p_almacen BIGINT,
    p_limite INTEGER,
    p_offset INTEGER
);
DROP FUNCTION IF EXISTS public.alm_listar_kardex(
    p_producto BIGINT,
    p_almacen BIGINT,
    p_limite INTEGER,
    p_offset INTEGER,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION public.alm_listar_kardex(
  p_producto BIGINT DEFAULT NULL,
  p_almacen BIGINT DEFAULT NULL,
  p_limite INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0,
  p_id_sucursal BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registros', COALESCE(json_agg(k ORDER BY k.fecha_confirmacion DESC,k.id DESC), '[]'::JSON))
  FROM (
    SELECT * FROM vw_alm_kardex
    WHERE (p_producto IS NULL OR id_producto=p_producto)
      AND (p_almacen IS NULL OR id_almacen=p_almacen)
      AND (p_id_sucursal IS NULL OR id_almacen IN (SELECT a.id FROM gen_almacen a WHERE a.id_sucursal=p_id_sucursal))
    ORDER BY fecha_confirmacion DESC,id DESC
    LIMIT LEAST(GREATEST(p_limite,1),200) OFFSET GREATEST(p_offset,0)
  ) k;
$$;
