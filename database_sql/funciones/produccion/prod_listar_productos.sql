-- Platos preparables de la sucursal. stock_libre = preparados sin asignar a un pedido
-- (preparación anticipada o cancelados con "guardar en stock"): cualquier pedido o sub-plato puede tomarlos.
CREATE OR REPLACE FUNCTION public.prod_listar_productos(p_sucursal BIGINT)
RETURNS JSON LANGUAGE sql AS $$
 SELECT COALESCE(json_agg(x ORDER BY nombre),'[]'::JSON) FROM (
  SELECT p.id,p.nombre,p.id_almacen_stock,r.id AS id_receta,r.version,a.nombre AS almacen,
   COALESCE(s.stock_actual,0) AS stock_actual,COALESCE(s.stock_reservado,0) AS stock_reservado,
   GREATEST(COALESCE(s.stock_actual-s.stock_reservado,0),0) AS stock_libre
  FROM pro_producto p JOIN pro_receta r ON r.id_producto=p.id AND r.estado=1 AND r.vigente
  JOIN gen_almacen a ON a.id=p.id_almacen_stock AND a.estado=1
  LEFT JOIN alm_producto_stock s ON s.id_producto=p.id AND s.id_almacen=p.id_almacen_stock AND s.estado=1
  WHERE p.estado=1 AND p.controla_stock AND a.id_sucursal=p_sucursal
 ) x;
$$;
