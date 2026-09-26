CREATE OR REPLACE FUNCTION public.ven_consumos_item(p_item BIGINT)
RETURNS TABLE(id_producto BIGINT, id_almacen BIGINT, id_unidad_medida BIGINT, cantidad NUMERIC)
LANGUAGE plpgsql AS $$
DECLARE d ven_pedido_detalle%ROWTYPE; pr pro_producto%ROWTYPE; r pro_receta%ROWTYPE;
  v_sucursal BIGINT; v RECORD; v_insumo pro_producto%ROWTYPE; v_cantidad NUMERIC;
BEGIN
  SELECT * INTO STRICT d FROM ven_pedido_detalle WHERE id = p_item;
  SELECT * INTO STRICT pr FROM pro_producto WHERE id = d.id_producto;
  SELECT id_sucursal INTO v_sucursal FROM ven_pedido WHERE id = d.id_pedido;
  IF pr.estado <> 1 OR NOT pr.disponible_venta THEN RAISE EXCEPTION 'Producto % no disponible', pr.nombre; END IF;
  IF d.id_receta IS NOT NULL THEN
    SELECT rec.* INTO r FROM pro_receta rec WHERE rec.id = d.id_receta AND rec.estado = 1 AND rec.id_producto = d.id_producto;
    IF NOT FOUND OR r.rendimiento_porciones <= 0 THEN RAISE EXCEPTION 'Receta inválida o inactiva'; END IF;
    IF pr.controla_stock THEN RAISE EXCEPTION 'Un producto no puede descontar stock directo y receta a la vez'; END IF;
    IF NOT EXISTS(SELECT 1 FROM pro_receta_insumo WHERE id_receta = r.id AND estado = 1) THEN RAISE EXCEPTION 'La receta no tiene insumos activos'; END IF;
    IF EXISTS(SELECT 1 FROM unnest(d.insumos_seleccionados) s(id)
      WHERE NOT EXISTS(SELECT 1 FROM pro_receta_insumo ri WHERE ri.id = s.id AND ri.id_receta = r.id AND ri.estado = 1))
    THEN RAISE EXCEPTION 'Insumos seleccionados ajenos a la receta'; END IF;
    IF EXISTS(SELECT 1 FROM pro_receta_insumo ri WHERE ri.id_receta = r.id AND ri.estado = 1 AND ri.grupo_sustitucion IS NOT NULL
      GROUP BY ri.grupo_sustitucion HAVING count(*) FILTER (WHERE ri.id = ANY(d.insumos_seleccionados)) > 1
        OR (bool_or(NOT ri.es_opcional) AND count(*) FILTER (WHERE ri.id = ANY(d.insumos_seleccionados)) <> 1))
    THEN RAISE EXCEPTION 'Seleccione un insumo por cada grupo obligatorio de sustitución'; END IF;
  ELSE
    IF pr.tipo_producto IN (3,4,5) THEN RAISE EXCEPTION 'El plato o trago requiere una receta activa'; END IF;
    IF cardinality(d.insumos_seleccionados) > 0 THEN RAISE EXCEPTION 'No se admiten insumos seleccionados sin receta'; END IF;
  END IF;

  FOR v IN
    SELECT pr.id AS producto, pr.id_unidad_medida AS unidad, d.cantidad AS consumo WHERE pr.controla_stock
    UNION ALL
    SELECT ri.id_producto_insumo, ri.id_unidad_medida,
      ri.cantidad * d.cantidad / r.rendimiento_porciones * (1 + ri.porcentaje_merma / 100)
      FROM pro_receta_insumo ri WHERE ri.id_receta = d.id_receta AND ri.estado = 1
        AND ((ri.grupo_sustitucion IS NULL AND NOT ri.es_opcional) OR ri.id = ANY(d.insumos_seleccionados))
    UNION ALL
    SELECT a.id_producto_insumo, a.id_unidad_medida, a.cantidad_insumo * d.cantidad
      FROM ven_pedido_detalle_adicional da JOIN pro_adicional a ON a.id = da.id_adicional
      WHERE da.id_pedido_detalle = d.id AND da.estado = 1 AND a.id_producto_insumo IS NOT NULL
  LOOP
    SELECT * INTO v_insumo FROM pro_producto WHERE id = v.producto AND estado = 1;
    IF NOT FOUND OR NOT v_insumo.controla_stock THEN RAISE EXCEPTION 'El insumo % debe estar activo y controlar stock', v.producto; END IF;
    IF NOT EXISTS(SELECT 1 FROM gen_almacen a WHERE a.id = v_insumo.id_almacen_stock AND a.id_sucursal = v_sucursal AND a.estado = 1)
    THEN RAISE EXCEPTION 'Configure un almacén activo de esta sucursal para el producto %', v_insumo.nombre; END IF;
    v_cantidad := round(v.consumo * ven_factor_unidad(v.unidad, v_insumo.id_unidad_medida),4);
    IF v_cantidad IS NULL OR v_cantidad <= 0 THEN RAISE EXCEPTION 'Consumo inválido o menor a la precisión de stock para %', v_insumo.nombre; END IF;
    id_producto := v_insumo.id;
    id_almacen := v_insumo.id_almacen_stock;
    id_unidad_medida := v_insumo.id_unidad_medida;
    cantidad := v_cantidad;
    RETURN NEXT;
  END LOOP;
END;
$$;
