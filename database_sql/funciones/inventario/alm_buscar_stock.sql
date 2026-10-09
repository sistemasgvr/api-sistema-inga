CREATE OR REPLACE FUNCTION public.alm_buscar_stock(p_producto BIGINT,p_almacen BIGINT,p_limite INTEGER,p_offset INTEGER,p_buscar TEXT,p_estado TEXT)
RETURNS JSON LANGUAGE sql AS $$
 WITH base AS (
  SELECT s.*,p.nombre AS producto_nombre,p.codigo_interno AS producto_codigo,p.id_unidad_medida,
    a.nombre AS almacen_nombre,u.simbolo AS simbolo_unidad,s.stock_actual<=s.stock_minimo AS alerta_activa,
    s.stock_actual-s.stock_reservado AS stock_disponible
  FROM alm_producto_stock s JOIN pro_producto p ON p.id=s.id_producto JOIN gen_almacen a ON a.id=s.id_almacen
  JOIN pro_unidad_medida u ON u.id=p.id_unidad_medida
  WHERE s.estado=1 AND (p_producto IS NULL OR s.id_producto=p_producto) AND (p_almacen IS NULL OR s.id_almacen=p_almacen)
    AND (COALESCE(p_buscar,'')='' OR concat_ws(' ',p.nombre,p.codigo_interno,a.nombre) ILIKE '%'||p_buscar||'%')
 ), filtrado AS (
  SELECT * FROM base WHERE COALESCE(p_estado,'todos')='todos' OR (p_estado='alertas' AND alerta_activa) OR (p_estado='normales' AND NOT alerta_activa)
 ), pagina AS (SELECT * FROM filtrado ORDER BY producto_nombre,id LIMIT LEAST(GREATEST(p_limite,1),200) OFFSET GREATEST(p_offset,0))
 SELECT json_build_object('registros',COALESCE((SELECT json_agg(p ORDER BY producto_nombre,id) FROM pagina p),'[]'::JSON),
  'total',(SELECT count(*) FROM filtrado),'resumen',json_build_object('total',(SELECT count(*) FROM base),
  'alertas',(SELECT count(*) FROM base WHERE alerta_activa),'normales',(SELECT count(*) FROM base WHERE NOT alerta_activa)));
$$;
