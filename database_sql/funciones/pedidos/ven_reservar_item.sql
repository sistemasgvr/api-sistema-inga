CREATE OR REPLACE FUNCTION ven_reservar_item(p_item BIGINT,p_usuario BIGINT) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE d ven_pedido_detalle%ROWTYPE; pr pro_producto%ROWTYPE; s alm_producto_stock%ROWTYPE; n NUMERIC; suc BIGINT;
BEGIN
  PERFORM alm_bloquear();
  SELECT * INTO STRICT d FROM ven_pedido_detalle WHERE id=p_item FOR UPDATE;
  SELECT * INTO STRICT pr FROM pro_producto WHERE id=d.id_producto;
  SELECT id_sucursal INTO suc FROM ven_pedido WHERE id=d.id_pedido;
  IF NOT pr.controla_stock OR NOT EXISTS(SELECT 1 FROM gen_almacen WHERE id=pr.id_almacen_stock AND id_sucursal=suc AND estado=1) THEN
    RAISE EXCEPTION 'Configure control de stock y almacén de la sucursal para %',pr.nombre; END IF;
  -- Las preparaciones personalizadas no se abastecen con platos estándar.
  IF d.id_receta IS NOT NULL AND (cardinality(d.insumos_seleccionados)>0 OR EXISTS(
    SELECT 1 FROM ven_pedido_detalle_adicional da JOIN pro_adicional a ON a.id=da.id_adicional
    WHERE da.id_pedido_detalle=d.id AND da.estado=1 AND a.id_producto_insumo IS NOT NULL)) THEN RETURN; END IF;
  SELECT * INTO s FROM alm_producto_stock WHERE id_producto=pr.id AND id_almacen=COALESCE(d.id_almacen_reserva,pr.id_almacen_stock) FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF s.estado<>1 THEN RAISE EXCEPTION 'Stock inactivo'; END IF;
  n:=LEAST(d.cantidad-d.cantidad_cancelada-d.cantidad_entregada-d.cantidad_reservada,s.stock_actual-s.stock_reservado);
  IF n>0 THEN
    -- Esas unidades ya no se elaboran: sus ingredientes apartados vuelven a estar disponibles.
    PERFORM ven_liberar_insumos(d.id,n,p_usuario);
    UPDATE alm_producto_stock SET stock_reservado=stock_reservado+n,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=s.id;
    UPDATE ven_pedido_detalle SET cantidad_reservada=cantidad_reservada+n,id_almacen_reserva=s.id_almacen,
      estado_preparacion=CASE WHEN cantidad_reservada+n+cantidad_entregada+cantidad_cancelada=cantidad THEN 4 ELSE estado_preparacion END,
      id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=d.id;
  END IF;
END $$;

-- cantidad_entregada es el TOTAL acumulado deseado; repetir la petición es idempotente.
