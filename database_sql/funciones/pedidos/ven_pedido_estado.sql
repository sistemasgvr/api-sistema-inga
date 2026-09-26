CREATE OR REPLACE FUNCTION public.ven_pedido_estado(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; v_destino INTEGER := (p_datos->>'estado_pedido')::INTEGER; v_pagado NUMERIC;
BEGIN
  -- Las transiciones que afectan inventario pasan por el mismo flujo que sus endpoints.
  IF v_destino = 2 THEN RETURN ven_pedido_comandar(p_id,p_item,p_datos,p_usuario); END IF;
  IF v_destino = 5 THEN RETURN ven_pedido_anular(p_id,p_item,p_datos,p_usuario); END IF;
  v := ven_bloquear_pedido(p_id);
  IF v_destino IS NULL OR v_destino NOT IN (3,4) THEN RAISE EXCEPTION 'Estado de destino inválido'; END IF;
  IF v.estado_pedido = v_destino THEN RETURN ven_obtener_pedido(p_id); END IF;
  IF NOT ((v.estado_pedido = 2 AND v_destino = 3) OR (v.estado_pedido = 3 AND v_destino = 4)) THEN RAISE EXCEPTION 'Transición de estado inválida: % a %',v.estado_pedido,v_destino; END IF;
  PERFORM ven_validar_turno_pedido(v.id_turno,v.id_sucursal);
  IF EXISTS(SELECT 1 FROM ven_pedido_detalle WHERE id_pedido = p_id AND estado = 1 AND tipo_linea <> 3 AND (id_comanda IS NULL OR NOT stock_descontado))
    THEN RAISE EXCEPTION 'Hay ítems pendientes de comandar'; END IF;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  IF v_destino = 4 THEN
    SELECT COALESCE(sum(monto),0) INTO v_pagado FROM ven_pago WHERE id_pedido = p_id AND estado = 1;
    SELECT * INTO v FROM ven_pedido WHERE id = p_id;
    IF v_pagado < v.monto_total THEN RAISE EXCEPTION 'El pedido requiere pagos registrados que cubran el total'; END IF;
    UPDATE ven_pedido SET monto_pagado = v_pagado,fecha_cierre = CURRENT_TIMESTAMP WHERE id = p_id;
  END IF;
  UPDATE ven_pedido SET estado_pedido = v_destino WHERE id = p_id;
  UPDATE ven_mesa SET estado_mesa = CASE WHEN v_destino = 3 THEN 3 ELSE 1 END,
    id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id = v.id_mesa;
  RETURN ven_obtener_pedido(p_id);
END;
$$;
