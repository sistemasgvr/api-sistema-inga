CREATE OR REPLACE FUNCTION public.ven_listar_cocina(p_sucursal BIGINT,p_estacion BIGINT,p_historial BOOLEAN,p_limite INTEGER,p_offset INTEGER)
RETURNS JSON LANGUAGE sql AS $$
 WITH lineas AS (
 SELECT d.*,p.codigo AS codigo_pedido,p.id_sucursal,p.id_mesa,me.codigo AS codigo_mesa,pr.nombre AS nombre_producto,
  pr.id_almacen_stock,pr.id_estacion,e.nombre AS estacion,c.numero AS numero_comanda,
  GREATEST(d.cantidad-d.cantidad_cancelada-d.cantidad_entregada,0) AS cantidad_pendiente
 FROM ven_pedido_detalle d JOIN ven_pedido p ON p.id=d.id_pedido JOIN pro_producto pr ON pr.id=d.id_producto
 JOIN ven_comanda c ON c.id=d.id_comanda LEFT JOIN ven_mesa me ON me.id=p.id_mesa LEFT JOIN gen_estacion e ON e.id=pr.id_estacion
 WHERE d.estado=1 AND p.estado=1 AND p.id_sucursal=p_sucursal AND (p_estacion IS NULL OR pr.id_estacion=p_estacion)
 AND CASE WHEN p_historial THEN d.estado_preparacion IN (5,6) ELSE p.estado_pedido IN (2,3) AND d.tipo_linea<>3 AND d.cantidad_entregada+d.cantidad_cancelada<d.cantidad END
 ), pagina AS (SELECT * FROM lineas ORDER BY fecha_creacion,id LIMIT LEAST(GREATEST(p_limite,1),200) OFFSET GREATEST(p_offset,0))
 SELECT json_build_object('registros',COALESCE((SELECT json_agg(x ORDER BY fecha_creacion,id) FROM pagina x),'[]'::JSON),'total',(SELECT count(*) FROM lineas));
$$;
