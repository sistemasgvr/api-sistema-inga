CREATE OR REPLACE FUNCTION public.prod_disponibilidad(p_receta BIGINT,p_almacen BIGINT,p_cantidad NUMERIC,p_item BIGINT DEFAULT NULL)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE r pro_receta%ROWTYPE; pr pro_producto%ROWTYPE; d ven_pedido_detalle%ROWTYPE; ingredientes JSONB; suc BIGINT;
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
  SELECT jsonb_agg(to_jsonb(x)) INTO ingredientes FROM (
   SELECT id_producto,id_almacen,id_unidad_medida,sum(cantidad/d.cantidad) AS por_unidad FROM ven_consumos_item(p_item) GROUP BY 1,2,3
  ) x;
 ELSE
  IF EXISTS(SELECT 1 FROM pro_receta_insumo WHERE id_receta=p_receta AND estado=1 AND grupo_sustitucion IS NOT NULL) THEN RAISE EXCEPTION 'Seleccione las sustituciones desde el pedido'; END IF;
  SELECT jsonb_agg(to_jsonb(x)) INTO ingredientes FROM (
   SELECT pi.id AS id_producto,pi.id_almacen_stock AS id_almacen,pi.id_unidad_medida,
    sum(ri.cantidad/r.rendimiento_porciones*(1+ri.porcentaje_merma/100)*ven_factor_unidad(ri.id_unidad_medida,pi.id_unidad_medida)) AS por_unidad
   FROM pro_receta_insumo ri JOIN pro_producto pi ON pi.id=ri.id_producto_insumo
   WHERE ri.id_receta=p_receta AND ri.estado=1 AND NOT ri.es_opcional GROUP BY pi.id
  ) x;
 END IF;
 IF ingredientes IS NULL THEN RAISE EXCEPTION 'La receta no tiene ingredientes'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_to_recordset(ingredientes) x(id_producto BIGINT,id_almacen BIGINT,por_unidad NUMERIC)
  LEFT JOIN pro_producto pi ON pi.id=x.id_producto LEFT JOIN gen_almacen a ON a.id=x.id_almacen
  WHERE pi.estado<>1 OR NOT pi.controla_stock OR a.id_sucursal IS DISTINCT FROM suc OR a.estado<>1 OR x.por_unidad<=0 OR x.id_producto=pr.id) THEN RAISE EXCEPTION 'Revise ingredientes y almacenes de la receta'; END IF;
 RETURN (WITH ins AS (
  -- Lo apartado al comandar esta misma línea también está disponible para prepararla.
  SELECT x.*,pi.nombre,u.simbolo,COALESCE(s.stock_actual-s.stock_reservado,0)+COALESCE((SELECT ri.cantidad FROM ven_pedido_reserva_insumo ri
      WHERE ri.id_pedido_detalle=p_item AND ri.id_producto=x.id_producto AND ri.id_almacen=x.id_almacen),0) AS disponible,
    round(x.por_unidad*p_cantidad,4) AS requerido
  FROM jsonb_to_recordset(ingredientes) x(id_producto BIGINT,id_almacen BIGINT,id_unidad_medida BIGINT,por_unidad NUMERIC)
  JOIN pro_producto pi ON pi.id=x.id_producto JOIN pro_unidad_medida u ON u.id=x.id_unidad_medida
  LEFT JOIN alm_producto_stock s ON s.id_producto=x.id_producto AND s.id_almacen=x.id_almacen AND s.estado=1
 ) SELECT json_build_object('registro',json_build_object('id_producto',pr.id,'id_receta',r.id,'id_almacen',p_almacen,
  'preparados',COALESCE((SELECT stock_actual FROM alm_producto_stock WHERE id_producto=pr.id AND id_almacen=p_almacen AND estado=1),0),
  'reservados',COALESCE((SELECT stock_reservado FROM alm_producto_stock WHERE id_producto=pr.id AND id_almacen=p_almacen AND estado=1),0),
  'posibles_preparar',COALESCE((SELECT floor(min(disponible/por_unidad)) FROM ins),0),
  'ingredientes',(SELECT json_agg(to_jsonb(ins)||jsonb_build_object('faltante',GREATEST(requerido-disponible,0))) FROM ins))));
END $$;
