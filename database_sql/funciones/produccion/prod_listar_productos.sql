CREATE OR REPLACE FUNCTION public.prod_listar_productos(p_sucursal BIGINT)
RETURNS JSON LANGUAGE sql AS $$
 SELECT COALESCE(json_agg(x ORDER BY nombre),'[]'::JSON) FROM (
  SELECT p.id,p.nombre,p.id_almacen_stock,r.id AS id_receta,r.version,a.nombre AS almacen
  FROM pro_producto p JOIN pro_receta r ON r.id_producto=p.id AND r.estado=1 AND r.vigente
  JOIN gen_almacen a ON a.id=p.id_almacen_stock AND a.estado=1
  WHERE p.estado=1 AND p.controla_stock AND a.id_sucursal=p_sucursal
 ) x;
$$;
