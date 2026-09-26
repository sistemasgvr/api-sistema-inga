CREATE OR REPLACE FUNCTION public.ven_pedido_anular(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; k alm_kardex%ROWTYPE; st alm_producto_stock%ROWTYPE; v_tipo SMALLINT;
BEGIN
  PERFORM ven_autorizar_anulacion(p_usuario,(p_datos->>'id_usuario_autoriza')::BIGINT,p_datos->>'motivo');
  v := ven_bloquear_pedido(p_id);
  IF v.estado_pedido = 5 THEN RETURN ven_obtener_pedido(p_id); END IF;
  IF v.estado_pedido NOT IN (1,2,3) THEN RAISE EXCEPTION 'No se puede anular un pedido pagado o cerrado'; END IF;
  IF v.monto_pagado > 0 OR EXISTS(SELECT 1 FROM ven_pago WHERE id_pedido = p_id AND estado = 1)
    OR EXISTS(SELECT 1 FROM ven_comprobante WHERE id_pedido = p_id AND estado = 1)
    THEN RAISE EXCEPTION 'El pedido tiene pagos o comprobantes; requiere el flujo de reverso de cobro'; END IF;
  SELECT o.valor_entero INTO v_tipo FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = 'KARDEX_TIPO' AND o.codigo = 'ANULACION_VENTA' AND l.estado = 1 AND o.estado = 1;
  IF v_tipo IS NULL THEN RAISE EXCEPTION 'Configure la opción KARDEX_TIPO / ANULACION_VENTA'; END IF;
  -- Se devuelve el movimiento original, nunca se vuelve a calcular la receta actual.
  FOR k IN SELECT ak.* FROM alm_kardex ak JOIN ven_pedido_detalle d ON d.id = ak.documento_id
    WHERE ak.documento_tipo = 'PEDIDO_DETALLE' AND ak.signo = -1 AND d.id_pedido = p_id
      AND NOT EXISTS(SELECT 1 FROM alm_kardex rev WHERE rev.documento_tipo = 'ANULACION_VENTA' AND rev.documento_id = ak.id AND rev.signo = 1)
    ORDER BY ak.id_almacen,ak.id_producto,ak.id
  LOOP
    SELECT * INTO st FROM alm_producto_stock WHERE id_almacen = k.id_almacen AND id_producto = k.id_producto FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'No existe el registro de stock para devolver el movimiento %',k.id; END IF;
    UPDATE alm_producto_stock SET stock_actual = stock_actual + k.cantidad,
      costo_promedio = round((stock_actual * costo_promedio + k.cantidad * COALESCE(k.costo_unitario,costo_promedio)) / (stock_actual + k.cantidad),4),
      id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id = st.id;
    INSERT INTO alm_kardex(id_almacen,id_producto,tipo_movimiento,signo,cantidad,id_unidad_medida,stock_anterior,stock_nuevo,costo_unitario,documento_tipo,documento_id,observacion,id_usuario_creacion,id_usuario_modificacion)
    VALUES(k.id_almacen,k.id_producto,v_tipo,1,k.cantidad,k.id_unidad_medida,st.stock_actual,st.stock_actual+k.cantidad,k.costo_unitario,
      'ANULACION_VENTA',k.id,'Anulación pedido ' || v.codigo || ': ' || btrim(p_datos->>'motivo'),p_usuario,p_usuario);
  END LOOP;
  UPDATE ven_pedido_detalle SET tipo_linea = 3,estado_preparacion = 6,stock_descontado = FALSE,
    id_usuario_autoriza = p_usuario,motivo_anulacion = btrim(p_datos->>'motivo'),
    id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id_pedido = p_id AND estado = 1 AND tipo_linea <> 3;
  UPDATE ven_comanda SET estado = 0,id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id_pedido = p_id AND estado = 1;
  UPDATE ven_pedido SET estado_pedido = 5,fecha_cierre = CURRENT_TIMESTAMP,id_usuario_autoriza = p_usuario,motivo_anulacion = btrim(p_datos->>'motivo') WHERE id = p_id;
  UPDATE ven_mesa SET estado_mesa = 1,id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id = v.id_mesa;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END;
$$;
