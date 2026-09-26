CREATE OR REPLACE FUNCTION public.ven_pedido_anular_item(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d ven_pedido_detalle%ROWTYPE;
BEGIN
  PERFORM ven_autorizar_anulacion(p_usuario,(p_datos->>'id_usuario_autoriza')::BIGINT,p_datos->>'motivo');
  v := ven_bloquear_pedido(p_id);
  IF v.estado_pedido NOT IN (1,2) THEN RAISE EXCEPTION 'El pedido no admite anulación de ítems'; END IF;
  SELECT * INTO d FROM ven_pedido_detalle WHERE id = p_item AND id_pedido = p_id AND estado = 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ítem no encontrado en el pedido' USING ERRCODE = 'P0002'; END IF;
  IF d.stock_descontado OR d.id_comanda IS NOT NULL THEN RAISE EXCEPTION 'No se puede anular un ítem comandado o con stock descontado'; END IF;
  IF d.tipo_linea = 3 THEN RETURN ven_obtener_pedido(p_id); END IF;
  UPDATE ven_pedido_detalle SET tipo_linea = 3,estado_preparacion = 6,
    id_usuario_autoriza = p_usuario,motivo_anulacion = btrim(p_datos->>'motivo'),
    id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id = p_item;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END;
$$;
