CREATE OR REPLACE FUNCTION ven_pedido_entregar(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d ven_pedido_detalle%ROWTYPE; pr pro_producto%ROWTYPE;
  objetivo NUMERIC:=(p_datos->>'cantidad_entregada')::NUMERIC; n NUMERIC; detalles JSONB; c RECORD;
BEGIN
  v:=ven_bloquear_pedido(p_id);
  PERFORM alm_bloquear();
  SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item AND id_pedido=p_id AND estado=1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ítem no encontrado' USING ERRCODE='P0002'; END IF;
  IF objetivo IS NULL OR objetivo<=0 OR objetivo<>round(objetivo,4) THEN RAISE EXCEPTION 'Cantidad entregada inválida'; END IF;
  IF objetivo=d.cantidad_entregada THEN RETURN ven_obtener_pedido(p_id); END IF;
  IF v.estado_pedido<>2 OR d.tipo_linea=3 OR d.id_comanda IS NULL OR objetivo<d.cantidad_entregada OR objetivo>d.cantidad-d.cantidad_cancelada THEN
    RAISE EXCEPTION 'Entrega no permitida'; END IF;
  PERFORM ven_reservar_item(p_item,p_usuario);
  SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item;
  SELECT * INTO STRICT pr FROM pro_producto WHERE id=d.id_producto;
  n:=objetivo-d.cantidad_entregada;
  IF n>d.cantidad_reservada THEN RAISE EXCEPTION 'Faltan platos preparados o productos disponibles'; END IF;
  UPDATE alm_producto_stock SET stock_reservado=stock_reservado-n,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
    WHERE id_producto=d.id_producto AND id_almacen=d.id_almacen_reserva;
  detalles:=jsonb_build_array(jsonb_build_object('id_producto',d.id_producto,'id_almacen',d.id_almacen_reserva,
      'id_unidad_medida',pr.id_unidad_medida,'cantidad',n,'signo',-1));
  -- En un producto directo, los extras no pasaron por producción.
  IF d.id_receta IS NULL THEN
    FOR c IN SELECT a.id_producto_insumo,p.id_almacen_stock,p.id_unidad_medida,
      round(a.cantidad_insumo*n*ven_factor_unidad(a.id_unidad_medida,p.id_unidad_medida),4) AS cantidad
      FROM ven_pedido_detalle_adicional da JOIN pro_adicional a ON a.id=da.id_adicional
      JOIN pro_producto p ON p.id=a.id_producto_insumo
      WHERE da.id_pedido_detalle=d.id AND da.estado=1
    LOOP
      IF NOT EXISTS(SELECT 1 FROM gen_almacen WHERE id=c.id_almacen_stock AND id_sucursal=v.id_sucursal AND estado=1) THEN
        RAISE EXCEPTION 'Almacén del adicional inválido'; END IF;
      detalles:=detalles||jsonb_build_array(jsonb_build_object('id_producto',c.id_producto_insumo,'id_almacen',c.id_almacen_stock,
        'id_unidad_medida',c.id_unidad_medida,'cantidad',c.cantidad,'signo',-1));
    END LOOP;
  END IF;
  PERFORM alm_aplicar('ENTREGA-'||d.id||'-'||objetivo,'SALIDA','VENTA','PEDIDO_DETALLE',d.id,detalles,p_usuario);
  UPDATE ven_pedido_detalle SET cantidad_reservada=cantidad_reservada-n,cantidad_entregada=objetivo,stock_descontado=TRUE,
    estado_preparacion=CASE WHEN objetivo=cantidad-cantidad_cancelada THEN 5 ELSE estado_preparacion END,
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=d.id;
  RETURN ven_obtener_pedido(p_id);
END $$;

-- Cancelación acumulada de unidades no entregadas. Libera el producto terminado
-- o lo da de baja por merma, sin devolver ingredientes consumidos.
