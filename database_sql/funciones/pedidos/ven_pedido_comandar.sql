CREATE OR REPLACE FUNCTION public.ven_pedido_comandar(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d RECORD; c RECORD; st alm_producto_stock%ROWTYPE;
  v_consumos JSONB := '[]'::JSONB; v_parte JSONB; v_pendientes JSONB := '[]'::JSONB;
  v_tipo SMALLINT; v_comanda BIGINT; v_numero INTEGER; v_estacion BIGINT;
BEGIN
  v := ven_bloquear_pedido(p_id);
  IF v.estado_pedido NOT IN (1,2) THEN RAISE EXCEPTION 'Solo se comandan pedidos abiertos o comandados'; END IF;
  PERFORM ven_validar_turno_pedido(v.id_turno,v.id_sucursal);
  IF NOT EXISTS(SELECT 1 FROM ven_pedido_detalle WHERE id_pedido = p_id AND estado = 1 AND tipo_linea <> 3) THEN RAISE EXCEPTION 'No se puede comandar un pedido sin ítems'; END IF;
  FOR d IN SELECT pd.id, pd.stock_descontado, pd.estado_preparacion, pr.id_estacion
    FROM ven_pedido_detalle pd JOIN pro_producto pr ON pr.id = pd.id_producto
    WHERE pd.id_pedido = p_id AND pd.estado = 1 AND pd.tipo_linea <> 3 AND pd.id_comanda IS NULL ORDER BY pd.id
  LOOP
    IF d.stock_descontado OR d.estado_preparacion <> 1 THEN RAISE EXCEPTION 'Ítem con estado de envío inconsistente'; END IF;
    IF NOT EXISTS(SELECT 1 FROM gen_estacion WHERE id = d.id_estacion AND estado = 1 AND id_sucursal = v.id_sucursal)
      THEN RAISE EXCEPTION 'El producto requiere una estación activa de esta sucursal'; END IF;
    IF EXISTS(SELECT 1 FROM ven_pedido_detalle_adicional da JOIN pro_adicional a ON a.id = da.id_adicional
      WHERE da.id_pedido_detalle = d.id AND da.estado = 1 AND a.estado <> 1) THEN RAISE EXCEPTION 'El pedido contiene adicionales inactivos'; END IF;
    -- Materializa cantidades una sola vez: la validación y el kardex usan exactamente el mismo consumo.
    SELECT COALESCE(jsonb_agg(to_jsonb(x) || jsonb_build_object('id_detalle', d.id)), '[]'::JSONB)
      INTO v_parte FROM ven_consumos_item(d.id) x;
    v_consumos := v_consumos || v_parte;
    v_pendientes := v_pendientes || jsonb_build_array(jsonb_build_object('id',d.id,'id_estacion',d.id_estacion));
  END LOOP;
  -- Reintentar sin nuevos ítems no vuelve a descontar ni genera otra comanda.
  IF jsonb_array_length(v_pendientes) = 0 THEN
    IF v.estado_pedido = 1 THEN RAISE EXCEPTION 'El pedido no tiene ítems pendientes para comandar'; END IF;
    RETURN ven_obtener_pedido(p_id);
  END IF;
  SELECT o.valor_entero INTO v_tipo FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = 'KARDEX_TIPO' AND o.codigo = 'VENTA' AND l.estado = 1 AND o.estado = 1;
  IF v_tipo IS NULL THEN RAISE EXCEPTION 'Configure la opción KARDEX_TIPO / VENTA'; END IF;

  -- Orden global de bloqueo para evitar que dos pedidos descuenten el mismo saldo.
  FOR c IN SELECT x.id_almacen,x.id_producto,sum(x.cantidad) AS cantidad
    FROM jsonb_to_recordset(v_consumos) AS x(id_almacen BIGINT,id_producto BIGINT,cantidad NUMERIC)
    GROUP BY x.id_almacen,x.id_producto ORDER BY x.id_almacen,x.id_producto
  LOOP
    SELECT * INTO st FROM alm_producto_stock WHERE id_almacen = c.id_almacen AND id_producto = c.id_producto FOR UPDATE;
    IF NOT FOUND OR st.estado <> 1 THEN RAISE EXCEPTION 'No existe stock activo del producto % en almacén %', c.id_producto,c.id_almacen; END IF;
    IF st.stock_actual - st.stock_reservado < c.cantidad THEN RAISE EXCEPTION 'Stock insuficiente del producto % en almacén % (disponible %, requerido %)',c.id_producto,c.id_almacen,st.stock_actual-st.stock_reservado,c.cantidad; END IF;
  END LOOP;
  FOR c IN SELECT x.id_almacen,x.id_producto,x.id_unidad_medida,x.id_detalle,sum(x.cantidad) AS cantidad
    FROM jsonb_to_recordset(v_consumos) AS x(id_almacen BIGINT,id_producto BIGINT,id_unidad_medida BIGINT,id_detalle BIGINT,cantidad NUMERIC)
    GROUP BY x.id_almacen,x.id_producto,x.id_unidad_medida,x.id_detalle ORDER BY x.id_almacen,x.id_producto,x.id_detalle
  LOOP
    SELECT * INTO STRICT st FROM alm_producto_stock WHERE id_almacen = c.id_almacen AND id_producto = c.id_producto;
    UPDATE alm_producto_stock SET stock_actual = stock_actual - c.cantidad,
      id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP WHERE id = st.id;
    INSERT INTO alm_kardex(id_almacen,id_producto,tipo_movimiento,signo,cantidad,id_unidad_medida,stock_anterior,stock_nuevo,costo_unitario,documento_tipo,documento_id,observacion,id_usuario_creacion,id_usuario_modificacion)
      VALUES(c.id_almacen,c.id_producto,v_tipo,-1,c.cantidad,c.id_unidad_medida,st.stock_actual,st.stock_actual-c.cantidad,st.costo_promedio,'PEDIDO_DETALLE',c.id_detalle,'Venta del pedido ' || v.codigo,p_usuario,p_usuario);
  END LOOP;
  FOR v_estacion IN SELECT DISTINCT x.id_estacion FROM jsonb_to_recordset(v_pendientes) AS x(id BIGINT,id_estacion BIGINT) ORDER BY x.id_estacion LOOP
    SELECT COALESCE(max(numero),0)+1 INTO v_numero FROM ven_comanda WHERE id_pedido = p_id AND id_estacion = v_estacion;
    INSERT INTO ven_comanda(id_pedido,id_estacion,numero,id_usuario_creacion,id_usuario_modificacion)
      VALUES(p_id,v_estacion,v_numero,p_usuario,p_usuario) RETURNING id INTO v_comanda;
    UPDATE ven_pedido_detalle SET id_comanda = v_comanda,estado_preparacion = 2,stock_descontado = TRUE,
      id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP
      WHERE id IN (SELECT x.id FROM jsonb_to_recordset(v_pendientes) AS x(id BIGINT,id_estacion BIGINT) WHERE x.id_estacion = v_estacion);
  END LOOP;
  UPDATE ven_pedido SET estado_pedido = 2 WHERE id = p_id;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END;
$$;
