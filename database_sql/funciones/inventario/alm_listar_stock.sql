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
      (EXISTS(SELECT 1 FROM pro_tipo_producto tp WHERE tp.id=p.tipo_producto AND tp.requiere_receta)
        OR EXISTS(SELECT 1 FROM pro_receta r WHERE r.id_producto=p.id AND r.estado=1 AND r.vigente)) AS tiene_receta,
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
