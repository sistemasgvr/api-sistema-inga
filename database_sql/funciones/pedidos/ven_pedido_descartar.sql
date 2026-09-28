-- Descarta un pedido recién abierto que nunca llegó a tener productos (el usuario no continuó).
-- A diferencia de ven_pedido_anular no hay stock, comandas ni cobros que revertir, por eso no
-- requiere autorización de ADMIN/CAJERO: solo puede hacerlo quien abrió el pedido.
CREATE OR REPLACE FUNCTION public.ven_pedido_descartar(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE;
BEGIN
  v := ven_bloquear_pedido(p_id);
  IF v.estado_pedido = 5 THEN RETURN ven_obtener_pedido(p_id); END IF;
  IF v.estado_pedido <> 1 THEN RAISE EXCEPTION 'Solo se puede descartar un pedido abierto'; END IF;
  IF v.id_usuario_creacion IS DISTINCT FROM p_usuario THEN
    RAISE EXCEPTION 'Solo el usuario que abrió el pedido puede descartarlo' USING ERRCODE = '42501';
  END IF;
  IF EXISTS(SELECT 1 FROM ven_pedido_detalle WHERE id_pedido = p_id AND estado = 1) THEN
    RAISE EXCEPTION 'El pedido ya tiene productos registrados; utilice la anulación';
  END IF;
  IF v.monto_pagado > 0 OR EXISTS(SELECT 1 FROM ven_pago WHERE id_pedido = p_id AND estado = 1)
    OR EXISTS(SELECT 1 FROM ven_comprobante WHERE id_pedido = p_id AND estado = 1)
    THEN RAISE EXCEPTION 'El pedido tiene pagos o comprobantes; no se puede descartar'; END IF;
  UPDATE ven_pedido SET estado_pedido = 5, fecha_cierre = CURRENT_TIMESTAMP,
    motivo_anulacion = COALESCE(NULLIF(btrim(p_datos->>'motivo'), ''), 'Descartado sin productos'),
    id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP
  WHERE id = p_id;
  UPDATE ven_mesa SET estado_mesa = 1, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP
  WHERE id = v.id_mesa;
  RETURN ven_obtener_pedido(p_id);
END;
$$;
