CREATE OR REPLACE FUNCTION public.ven_pedido_preparacion(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d ven_pedido_detalle%ROWTYPE; destino INTEGER:=(p_datos->>'estado_preparacion')::INTEGER;
BEGIN
 v:=ven_bloquear_pedido(p_id);
 SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item AND id_pedido=p_id AND estado=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Detalle no encontrado' USING ERRCODE='P0002'; END IF;
 IF v.estado_pedido NOT IN (2,3) OR d.tipo_linea=3 OR d.id_comanda IS NULL OR d.cantidad_entregada+d.cantidad_cancelada>=d.cantidad THEN RAISE EXCEPTION 'El detalle no admite preparación'; END IF;
 IF destino NOT IN (3,4) OR destino IS NULL THEN RAISE EXCEPTION 'Estado de preparación inválido'; END IF;
 IF destino=d.estado_preparacion THEN RETURN ven_obtener_pedido(p_id); END IF;
 IF destino=3 AND d.estado_preparacion<>2 THEN RAISE EXCEPTION 'Solo un detalle enviado puede iniciar preparación'; END IF;
 IF destino=4 THEN
  IF d.estado_preparacion NOT IN (2,3) THEN RAISE EXCEPTION 'Transición de preparación inválida'; END IF;
  PERFORM ven_reservar_item(p_item,p_usuario);
  SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item;
  IF d.cantidad_reservada<d.cantidad-d.cantidad_entregada-d.cantidad_cancelada THEN RAISE EXCEPTION 'Primero confirme la producción de los platos faltantes'; END IF;
 END IF;
 UPDATE ven_pedido_detalle SET estado_preparacion=destino,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=p_item;
 RETURN ven_obtener_pedido(p_id);
END $$;
