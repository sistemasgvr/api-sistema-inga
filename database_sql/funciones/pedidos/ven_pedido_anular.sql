CREATE OR REPLACE FUNCTION public.ven_pedido_anular(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d RECORD;
BEGIN
  PERFORM ven_autorizar_anulacion(p_usuario,(p_datos->>'id_usuario_autoriza')::BIGINT,p_datos->>'motivo');
  v:=ven_bloquear_pedido(p_id);
  IF v.estado_pedido=5 THEN RETURN ven_obtener_pedido(p_id); END IF;
  IF v.estado_pedido NOT IN (1,2,3) THEN RAISE EXCEPTION 'No se puede anular un pedido pagado o cerrado'; END IF;
  IF v.monto_pagado>0 OR EXISTS(SELECT 1 FROM ven_pago WHERE id_pedido=p_id AND estado=1)
    OR EXISTS(SELECT 1 FROM ven_comprobante WHERE id_pedido=p_id AND estado=1) THEN
    RAISE EXCEPTION 'El pedido tiene pagos o comprobantes; requiere reverso de cobro'; END IF;
  IF EXISTS(SELECT 1 FROM ven_pedido_detalle WHERE id_pedido=p_id AND estado=1 AND cantidad_entregada>0) THEN
    RAISE EXCEPTION 'El pedido tiene productos entregados; requiere devolución física y reverso comercial'; END IF;
  FOR d IN SELECT * FROM ven_pedido_detalle WHERE id_pedido=p_id AND estado=1 AND tipo_linea<>3 ORDER BY id LOOP
    PERFORM ven_cancelar_stock_item(d.id,d.cantidad,p_datos->>'destino_preparado',p_usuario);
    UPDATE ven_pedido_detalle SET id_usuario_autoriza=p_usuario,motivo_anulacion=btrim(p_datos->>'motivo'),
      id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=d.id;
  END LOOP;
  UPDATE ven_comanda SET estado=0,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id_pedido=p_id AND estado=1;
  UPDATE ven_pedido SET estado_pedido=5,fecha_cierre=CURRENT_TIMESTAMP,id_usuario_autoriza=p_usuario,motivo_anulacion=btrim(p_datos->>'motivo'),
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=p_id;
  UPDATE ven_mesa SET estado_mesa=1,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=v.id_mesa;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END $$;
