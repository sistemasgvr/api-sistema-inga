-- ¿Alcanza el stock libre para preparar p_cantidad de una receta estándar (con sub-platos)?
DROP FUNCTION IF EXISTS prod_alcanza(p_receta BIGINT, p_cantidad NUMERIC, p_sucursal BIGINT);
CREATE OR REPLACE FUNCTION prod_alcanza(p_receta BIGINT,p_cantidad NUMERIC,p_sucursal BIGINT) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  RETURN NOT EXISTS(SELECT 1 FROM jsonb_to_recordset(prod_explosion(p_receta,p_cantidad,p_sucursal)) x(id_producto BIGINT,id_almacen BIGINT,cantidad NUMERIC)
    LEFT JOIN alm_producto_stock s ON s.id_producto=x.id_producto AND s.id_almacen=x.id_almacen AND s.estado=1
    GROUP BY x.id_producto,x.id_almacen,s.stock_actual,s.stock_reservado HAVING sum(x.cantidad)>COALESCE(s.stock_actual-s.stock_reservado,0));
EXCEPTION WHEN raise_exception THEN RETURN FALSE; -- Cantidades por debajo de la precisión de stock.
END $$;

-- Componentes para preparar p_cantidad, agrupados por sub-plato (id_producto_origen/origen/ruta).
-- preparado = se usa un sub-plato ya preparado en lugar de sus ingredientes.
-- Con p_item se arma desde lo apartado al comandar esa línea; sin reserva, con el stock del momento.
DROP FUNCTION IF EXISTS public.prod_disponibilidad(p_receta BIGINT, p_almacen BIGINT, p_cantidad NUMERIC, p_item BIGINT);
CREATE OR REPLACE FUNCTION public.prod_disponibilidad(p_receta BIGINT,p_almacen BIGINT,p_cantidad NUMERIC,p_item BIGINT DEFAULT NULL)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE r pro_receta%ROWTYPE; pr pro_producto%ROWTYPE; d ven_pedido_detalle%ROWTYPE; necesidades JSONB:='[]'; libre JSONB:='{}';
  suc BIGINT; pendientes NUMERIC; c RECORD; reservado BOOLEAN:=FALSE; con_subplatos BOOLEAN:=FALSE; filas JSONB; posibles NUMERIC; lo NUMERIC; hi NUMERIC; mid NUMERIC;
BEGIN
 IF p_cantidad IS NULL OR p_cantidad<=0 THEN RAISE EXCEPTION 'Cantidad solicitada inválida'; END IF;
 SELECT * INTO r FROM pro_receta WHERE id=p_receta AND estado=1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Receta no encontrada' USING ERRCODE='P0002'; END IF;
 SELECT * INTO pr FROM pro_producto WHERE id=r.id_producto;
 SELECT id_sucursal INTO suc FROM gen_almacen WHERE id=p_almacen AND estado=1;
 IF suc IS NULL THEN RAISE EXCEPTION 'Almacén inválido'; END IF;
 IF p_item IS NOT NULL THEN
  SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item AND id_receta=p_receta AND id_producto=pr.id;
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM ven_pedido WHERE id=d.id_pedido AND id_sucursal=suc) THEN RAISE EXCEPTION 'Pedido y receta incompatibles'; END IF;
  pendientes:=d.cantidad-d.cantidad_cancelada-d.cantidad_entregada-d.cantidad_reservada;
  reservado:=pendientes>0 AND EXISTS(SELECT 1 FROM ven_pedido_reserva_insumo WHERE id_pedido_detalle=p_item AND cantidad>0);
  IF reservado THEN
   SELECT jsonb_agg(jsonb_build_object('id_producto',ri.id_producto,'id_almacen',ri.id_almacen,'id_unidad_medida',p.id_unidad_medida,
     'cantidad',round(ri.cantidad*p_cantidad/pendientes,4),'id_producto_origen',ri.id_producto_origen,'preparado',ri.es_preparado))
    INTO necesidades FROM ven_pedido_reserva_insumo ri JOIN pro_producto p ON p.id=ri.id_producto
    WHERE ri.id_pedido_detalle=p_item AND ri.cantidad>0;
  ELSE
   FOR c IN SELECT x.*,round(x.cantidad*p_cantidad/d.cantidad,4) AS parte FROM ven_consumos_item(p_item) x LOOP
    IF c.es_subplato THEN
     SELECT x.p_necesidades,x.p_libre INTO necesidades,libre FROM prod_cubrir_subplato(necesidades,libre,c.id_producto,c.id_almacen,
       c.id_unidad_medida,c.parte,NULL,c.ruta,suc) x;
    ELSE
     necesidades:=necesidades||jsonb_build_array(jsonb_build_object('id_producto',c.id_producto,'id_almacen',c.id_almacen,
       'id_unidad_medida',c.id_unidad_medida,'cantidad',c.parte,'id_producto_origen',NULL,'preparado',false));
    END IF;
   END LOOP;
  END IF;
 ELSE
  IF EXISTS(SELECT 1 FROM pro_receta_insumo WHERE id_receta=p_receta AND estado=1 AND grupo_sustitucion IS NOT NULL) THEN RAISE EXCEPTION 'Seleccione las sustituciones desde el pedido'; END IF;
  necesidades:=prod_explosion(p_receta,p_cantidad,suc);
  con_subplatos:=EXISTS(SELECT 1 FROM pro_explotar_receta(p_receta,1,NULL,suc,FALSE) x WHERE x.es_subplato);
 END IF;
 IF necesidades IS NULL OR jsonb_array_length(necesidades)=0 THEN RAISE EXCEPTION 'La receta no tiene ingredientes'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_to_recordset(necesidades) x(id_producto BIGINT,cantidad NUMERIC) WHERE x.cantidad<=0 OR x.id_producto=pr.id) THEN
  RAISE EXCEPTION 'Revise ingredientes y almacenes de la receta'; END IF;

 -- Lo apartado al comandar esta misma línea también está disponible para prepararla.
 SELECT jsonb_agg(jsonb_build_object('id_producto',g.id_producto,'id_almacen',g.id_almacen,'id_unidad_medida',g.id_unidad_medida,
   'id_producto_origen',g.id_producto_origen,'preparado',g.preparado,'requerido',g.requerido,
   'disponible',COALESCE(s.stock_actual-s.stock_reservado,0)+COALESCE((SELECT sum(ri.cantidad) FROM ven_pedido_reserva_insumo ri
     WHERE ri.id_pedido_detalle=p_item AND ri.id_producto=g.id_producto AND ri.id_almacen=g.id_almacen),0),
   'total',g.total)) INTO filas
 FROM (SELECT x.id_producto,x.id_almacen,x.id_unidad_medida,x.id_producto_origen,bool_or(x.preparado) AS preparado,sum(x.cantidad) AS requerido,
   sum(sum(x.cantidad)) OVER (PARTITION BY x.id_producto,x.id_almacen) AS total
   FROM jsonb_to_recordset(necesidades) x(id_producto BIGINT,id_almacen BIGINT,id_unidad_medida BIGINT,cantidad NUMERIC,id_producto_origen BIGINT,preparado BOOLEAN)
   GROUP BY 1,2,3,4) g
 LEFT JOIN alm_producto_stock s ON s.id_producto=g.id_producto AND s.id_almacen=g.id_almacen AND s.estado=1;

 IF con_subplatos THEN
  -- Con sub-platos el consumo no es lineal (primero platos libres, luego ingredientes): búsqueda binaria.
  -- Con p_item el consumo es lineal: lo apartado (o la receta personalizada) por unidad.
  IF NOT prod_alcanza(p_receta,1,suc) THEN posibles:=0;
  ELSE
   lo:=1; hi:=2;
   WHILE hi<=100000 AND prod_alcanza(p_receta,hi,suc) LOOP lo:=hi; hi:=hi*2; END LOOP;
   WHILE hi-lo>1 LOOP
    mid:=floor((lo+hi)/2);
    IF prod_alcanza(p_receta,mid,suc) THEN lo:=mid; ELSE hi:=mid; END IF;
   END LOOP;
   posibles:=lo;
  END IF;
 ELSE
  SELECT floor(min(x.disponible/(x.total/p_cantidad))) INTO posibles FROM jsonb_to_recordset(filas) x(id_producto BIGINT,id_almacen BIGINT,id_unidad_medida BIGINT,id_producto_origen BIGINT,preparado BOOLEAN,requerido NUMERIC,disponible NUMERIC,total NUMERIC);
 END IF;

 RETURN (WITH ins AS (
  SELECT t.id_producto,t.id_almacen,t.id_unidad_medida,round(t.requerido/p_cantidad,6) AS por_unidad,pi.nombre,u.simbolo,
    t.disponible,round(t.requerido,4) AS requerido,
    -- El faltante del producto se reparte entre los sub-platos que lo usan.
    round(GREATEST(t.total-t.disponible,0)*t.requerido/t.total,4) AS faltante,
    t.id_producto_origen,o.nombre AS origen,COALESCE(o.nombre,pr.nombre) AS ruta,t.preparado
  FROM jsonb_to_recordset(filas) AS t(id_producto BIGINT,id_almacen BIGINT,id_unidad_medida BIGINT,id_producto_origen BIGINT,preparado BOOLEAN,requerido NUMERIC,disponible NUMERIC,total NUMERIC)
  JOIN pro_producto pi ON pi.id=t.id_producto JOIN pro_unidad_medida u ON u.id=t.id_unidad_medida
  LEFT JOIN pro_producto o ON o.id=t.id_producto_origen
 ) SELECT json_build_object('registro',json_build_object('id_producto',pr.id,'id_receta',r.id,'id_almacen',p_almacen,
  'preparados',COALESCE((SELECT stock_actual FROM alm_producto_stock WHERE id_producto=pr.id AND id_almacen=p_almacen AND estado=1),0),
  'reservados',COALESCE((SELECT stock_reservado FROM alm_producto_stock WHERE id_producto=pr.id AND id_almacen=p_almacen AND estado=1),0),
  'libres',COALESCE((SELECT GREATEST(stock_actual-stock_reservado,0) FROM alm_producto_stock WHERE id_producto=pr.id AND id_almacen=p_almacen AND estado=1),0),
  'posibles_preparar',GREATEST(COALESCE(posibles,0),0),
  'ingredientes',(SELECT json_agg(to_jsonb(ins) ORDER BY ins.id_producto_origen NULLS FIRST,ins.preparado DESC,ins.nombre) FROM ins))));
END $$;
