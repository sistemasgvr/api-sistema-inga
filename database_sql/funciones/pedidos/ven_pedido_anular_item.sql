CREATE OR REPLACE FUNCTION public.ven_pedido_anular_item(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d ven_pedido_detalle%ROWTYPE;
BEGIN
  PERFORM ven_autorizar_anulacion(p_usuario,(p_datos->>'id_usuario_autoriza')::BIGINT,p_datos->>'motivo');
  v:=ven_bloquear_pedido(p_id);
  IF v.estado_pedido NOT IN (1,2) THEN RAISE EXCEPTION 'El pedido no admite anulación de ítems'; END IF;
  IF EXISTS(SELECT 1 FROM ven_pago WHERE id_pedido=p_id AND estado=1) OR EXISTS(SELECT 1 FROM ven_comprobante WHERE id_pedido=p_id AND estado=1) THEN
    RAISE EXCEPTION 'El pedido tiene pagos o comprobantes; requiere reverso de cobro'; END IF;
  SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item AND id_pedido=p_id AND estado=1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ítem no encontrado' USING ERRCODE='P0002'; END IF;
  PERFORM ven_cancelar_stock_item(d.id,COALESCE((p_datos->>'cantidad_cancelada')::NUMERIC,d.cantidad-d.cantidad_entregada),p_datos->>'destino_preparado',p_usuario);
  UPDATE ven_pedido_detalle SET id_usuario_autoriza=p_usuario,motivo_anulacion=btrim(p_datos->>'motivo'),
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=d.id;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END $$;
