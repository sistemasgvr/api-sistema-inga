-- Oculta productos eliminados del stock, sus totales y alertas.
BEGIN;
CREATE OR REPLACE FUNCTION public.alm_listar_stock(
  p_producto BIGINT DEFAULT NULL,
  p_almacen BIGINT DEFAULT NULL,
  p_limite INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registros', COALESCE(json_agg(s ORDER BY s.id), '[]'::JSON))
  FROM (
    SELECT 
      aps.id,
      aps.id_almacen,
      a.nombre AS almacen_nombre,
      aps.id_producto,
      p.codigo_interno AS producto_codigo,
      p.nombre AS producto_nombre,
      p.tipo_producto,
      um.simbolo AS simbolo_unidad,
      aps.stock_actual,
      aps.stock_minimo,
      aps.stock_reservado,
      aps.costo_promedio,
      (aps.stock_actual <= aps.stock_minimo) AS alerta_activa,
      aps.fecha_modificacion
    FROM alm_producto_stock aps
    JOIN pro_producto p ON p.id = aps.id_producto
    JOIN gen_almacen a ON a.id = aps.id_almacen
    JOIN pro_unidad_medida um ON um.id = p.id_unidad_medida
    WHERE aps.estado = 1
      AND p.estado = 1
      AND (p_producto IS NULL OR aps.id_producto = p_producto)
      AND (p_almacen IS NULL OR aps.id_almacen = p_almacen)
    ORDER BY aps.id DESC
    LIMIT LEAST(GREATEST(p_limite, 1), 200) OFFSET GREATEST(p_offset, 0)
  ) s;
$$;

CREATE OR REPLACE FUNCTION public.alm_buscar_stock(p_producto BIGINT,p_almacen BIGINT,p_limite INTEGER,p_offset INTEGER,p_buscar TEXT,p_estado TEXT)
RETURNS JSON LANGUAGE sql AS $$
 WITH base AS (
  SELECT s.*,p.nombre AS producto_nombre,p.codigo_interno AS producto_codigo,p.id_unidad_medida,
    a.nombre AS almacen_nombre,u.simbolo AS simbolo_unidad,s.stock_actual<=s.stock_minimo AS alerta_activa,
    s.stock_actual-s.stock_reservado AS stock_disponible
  FROM alm_producto_stock s JOIN pro_producto p ON p.id=s.id_producto JOIN gen_almacen a ON a.id=s.id_almacen
  JOIN pro_unidad_medida u ON u.id=p.id_unidad_medida
  WHERE s.estado=1 AND p.estado=1 AND (p_producto IS NULL OR s.id_producto=p_producto) AND (p_almacen IS NULL OR s.id_almacen=p_almacen)
    AND (COALESCE(p_buscar,'')='' OR concat_ws(' ',p.nombre,p.codigo_interno,a.nombre) ILIKE '%'||p_buscar||'%')
 ), filtrado AS (
  SELECT * FROM base WHERE COALESCE(p_estado,'todos')='todos' OR (p_estado='alertas' AND alerta_activa) OR (p_estado='normales' AND NOT alerta_activa)
 ), pagina AS (SELECT * FROM filtrado ORDER BY producto_nombre,id LIMIT LEAST(GREATEST(p_limite,1),200) OFFSET GREATEST(p_offset,0))
 SELECT json_build_object('registros',COALESCE((SELECT json_agg(p ORDER BY producto_nombre,id) FROM pagina p),'[]'::JSON),
  'total',(SELECT count(*) FROM filtrado),'resumen',json_build_object('total',(SELECT count(*) FROM base),
  'alertas',(SELECT count(*) FROM base WHERE alerta_activa),'normales',(SELECT count(*) FROM base WHERE NOT alerta_activa)));
$$;

COMMIT;

