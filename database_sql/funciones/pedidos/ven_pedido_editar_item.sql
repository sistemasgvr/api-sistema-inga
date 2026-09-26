CREATE OR REPLACE FUNCTION public.ven_pedido_editar_item(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d ven_pedido_detalle%ROWTYPE; v_cantidad NUMERIC;
BEGIN
  v := ven_bloquear_pedido(p_id);
  IF v.estado_pedido NOT IN (1,2) THEN RAISE EXCEPTION 'El pedido no admite edición'; END IF;
  PERFORM ven_validar_turno_pedido(v.id_turno, v.id_sucursal);
  SELECT * INTO d FROM ven_pedido_detalle WHERE id = p_item AND id_pedido = p_id AND estado = 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ítem no encontrado en el pedido' USING ERRCODE = 'P0002'; END IF;
  IF d.tipo_linea = 3 OR d.stock_descontado OR d.id_comanda IS NOT NULL OR d.estado_preparacion <> 1 THEN RAISE EXCEPTION 'Solo se editan ítems pendientes sin comanda'; END IF;
  IF NOT (p_datos ? 'cantidad' OR p_datos ? 'observacion') THEN RAISE EXCEPTION 'Indique cantidad u observación'; END IF;
  v_cantidad := COALESCE((p_datos->>'cantidad')::NUMERIC,d.cantidad);
  IF v_cantidad <= 0 OR v_cantidad <> round(v_cantidad,4) THEN RAISE EXCEPTION 'La cantidad debe ser positiva con máximo 4 decimales'; END IF;
  UPDATE ven_pedido_detalle SET cantidad = v_cantidad,
    observacion = CASE WHEN p_datos ? 'observacion' THEN p_datos->>'observacion' ELSE observacion END,
    id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id = p_item;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END;
$$;
