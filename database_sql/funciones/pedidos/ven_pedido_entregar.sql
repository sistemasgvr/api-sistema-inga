-- cantidad_entregada es el TOTAL acumulado deseado; repetir la petición es idempotente.
DROP FUNCTION IF EXISTS ven_pedido_entregar(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT);
CREATE OR REPLACE FUNCTION ven_pedido_entregar(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d ven_pedido_detalle%ROWTYPE; pr pro_producto%ROWTYPE;
  objetivo NUMERIC:=(p_datos->>'cantidad_entregada')::NUMERIC; n NUMERIC; detalles JSONB; c RECORD;
  v_directo BOOLEAN := FALSE; usado NUMERIC; resto NUMERIC; insumos JSONB;
BEGIN
  v:=ven_bloquear_pedido(p_id, (p_datos->>'id_sucursal_sesion')::BIGINT);
  PERFORM alm_bloquear();
  SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item AND id_pedido=p_id AND estado=1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ítem no encontrado' USING ERRCODE='P0002'; END IF;
  IF objetivo IS NULL OR objetivo<=0 OR objetivo<>round(objetivo,4) THEN RAISE EXCEPTION 'Cantidad entregada inválida'; END IF;
  IF objetivo=d.cantidad_entregada THEN RETURN ven_obtener_pedido(p_id); END IF;
  IF v.estado_pedido NOT IN (2,3) OR d.tipo_linea=3 OR d.id_comanda IS NULL OR objetivo<d.cantidad_entregada OR objetivo>d.cantidad-d.cantidad_cancelada THEN
    RAISE EXCEPTION 'Entrega no permitida'; END IF;
  SELECT COALESCE(e.modo_entrega_directa,0)=1 INTO v_directo
    FROM gen_sucursal s JOIN gen_empresa e ON e.id=s.id_empresa WHERE s.id=v.id_sucursal;
  PERFORM ven_reservar_item(p_item,p_usuario);
  SELECT * INTO d FROM ven_pedido_detalle WHERE id=p_item;
  SELECT * INTO STRICT pr FROM pro_producto WHERE id=d.id_producto;
  n:=objetivo-d.cantidad_entregada;
  -- Se entrega con lo ya preparado (su reserva se consume). En entrega directa,
  -- lo que falta se cubre con los insumos apartados al comandar: no se exige el
  -- paso de producción. Fuera de ese modo, sin plato preparado no hay entrega.
  usado:=LEAST(n,d.cantidad_reservada);
  resto:=n-usado;
  insumos:='[]'::JSONB;
  IF resto>0 THEN
    IF NOT v_directo THEN RAISE EXCEPTION 'Faltan platos preparados o productos disponibles'; END IF;
    -- Libera antes de tocar cantidad_reservada: la proporción usa lo pendiente actual.
    insumos:=ven_liberar_insumos(p_item,resto,p_usuario);
    IF COALESCE((SELECT sum((x->>'cantidad')::NUMERIC) FROM jsonb_array_elements(insumos) x),0)<=0 THEN
      RAISE EXCEPTION 'No hay insumos apartados para entregar el plato'; END IF;
  END IF;
  detalles:='[]'::JSONB;
  IF usado>0 THEN
    UPDATE alm_producto_stock SET stock_reservado=stock_reservado-usado,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
      WHERE id_producto=d.id_producto AND id_almacen=d.id_almacen_reserva;
    detalles:=detalles||jsonb_build_array(jsonb_build_object('id_producto',d.id_producto,'id_almacen',d.id_almacen_reserva,
      'id_unidad_medida',pr.id_unidad_medida,'cantidad',usado,'signo',-1));
  END IF;
  detalles:=detalles||insumos;
  IF jsonb_array_length(detalles)=0 THEN RAISE EXCEPTION 'No hay stock que descontar para la entrega'; END IF;
  -- En un producto directo, los extras no pasaron por producción.
  IF d.id_receta IS NULL THEN
    FOR c IN SELECT a.id_producto_insumo,p.id_almacen_stock,p.id_unidad_medida,
      round(a.cantidad_insumo*usado*ven_factor_unidad(a.id_unidad_medida,p.id_unidad_medida),4) AS cantidad
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
  UPDATE ven_pedido_detalle SET cantidad_reservada=cantidad_reservada-usado,cantidad_entregada=objetivo,stock_descontado=TRUE,
    estado_preparacion=CASE WHEN objetivo=cantidad-cantidad_cancelada THEN 5 ELSE estado_preparacion END,
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=d.id;
  RETURN ven_obtener_pedido(p_id);
END $$;
