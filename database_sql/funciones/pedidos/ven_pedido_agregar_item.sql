CREATE OR REPLACE FUNCTION public.ven_pedido_agregar_item(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; pr pro_producto%ROWTYPE; v_receta BIGINT := (p_datos->>'id_receta')::BIGINT;
  v_cantidad NUMERIC := (p_datos->>'cantidad')::NUMERIC; v_precio NUMERIC; v_det BIGINT; v_ad JSONB; a pro_adicional%ROWTYPE;
  v_seleccion BIGINT[];
BEGIN
  v := ven_bloquear_pedido(p_id);
  IF v.estado_pedido NOT IN (1,2) THEN RAISE EXCEPTION 'Solo se agregan ítems a pedidos abiertos o comandados'; END IF;
  PERFORM ven_validar_turno_pedido(v.id_turno, v.id_sucursal);
  SELECT * INTO pr FROM pro_producto WHERE id = (p_datos->>'id_producto')::BIGINT AND estado = 1 AND disponible_venta;
  IF NOT FOUND THEN RAISE EXCEPTION 'Producto no disponible'; END IF;
  IF NOT EXISTS(SELECT 1 FROM gen_estacion WHERE id = pr.id_estacion AND estado = 1 AND id_sucursal = v.id_sucursal)
  THEN RAISE EXCEPTION 'El producto requiere una estación activa de esta sucursal'; END IF;
  IF v_cantidad IS NULL OR v_cantidad <= 0 OR v_cantidad <> round(v_cantidad,4) THEN RAISE EXCEPTION 'La cantidad debe ser positiva con máximo 4 decimales'; END IF;
  v_precio := COALESCE((p_datos->>'precio_unitario')::NUMERIC,pr.precio_venta);
  IF v_precio < 0 OR v_precio <> round(v_precio,2) THEN RAISE EXCEPTION 'Precio inválido'; END IF;
  IF v_receta IS NULL AND NOT pr.controla_stock THEN
    SELECT id INTO v_receta FROM pro_receta WHERE id_producto = pr.id AND estado = 1 AND vigente;
  END IF;
  SELECT COALESCE(array_agg(x::BIGINT),'{}'::BIGINT[]) INTO v_seleccion
    FROM jsonb_array_elements_text(COALESCE(NULLIF(p_datos->'insumos_seleccionados','null'::JSONB),'[]'::JSONB)) x;
  IF cardinality(v_seleccion) <> (SELECT count(DISTINCT x) FROM unnest(v_seleccion) x) THEN RAISE EXCEPTION 'Insumos seleccionados duplicados'; END IF;
  INSERT INTO ven_pedido_detalle(id_pedido,id_producto,id_receta,cantidad,precio_unitario,monto_subtotal,observacion,afecto_igv,insumos_seleccionados,id_usuario_creacion,id_usuario_modificacion)
  VALUES(p_id,pr.id,v_receta,v_cantidad,v_precio,0,p_datos->>'observacion',pr.afecto_igv,v_seleccion,p_usuario,p_usuario) RETURNING id INTO v_det;
  FOR v_ad IN SELECT * FROM jsonb_array_elements(COALESCE(NULLIF(p_datos->'adicionales','null'::JSONB),'[]'::JSONB)) LOOP
    SELECT * INTO a FROM pro_adicional WHERE id = (v_ad->>'id_adicional')::BIGINT AND id_producto = pr.id AND estado = 1;
    IF NOT FOUND OR a.precio_adicional < 0 THEN RAISE EXCEPTION 'Adicional inválido para este producto'; END IF;
    IF EXISTS(SELECT 1 FROM ven_pedido_detalle_adicional WHERE id_pedido_detalle = v_det AND id_adicional = a.id) THEN RAISE EXCEPTION 'Adicional duplicado'; END IF;
    INSERT INTO ven_pedido_detalle_adicional(id_pedido_detalle,id_adicional,precio_adicional,id_usuario_creacion,id_usuario_modificacion)
    VALUES(v_det,a.id,a.precio_adicional,p_usuario,p_usuario);
  END LOOP;
  -- Valida receta, selección, almacenes y unidades sin descontar existencias todavía.
  PERFORM * FROM ven_consumos_item(v_det);
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END;
$$;
