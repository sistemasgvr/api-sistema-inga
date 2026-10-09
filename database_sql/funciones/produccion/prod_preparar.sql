-- Registra una preparación terminada: consumo y producción son atómicos.
-- codigo es único; un reintento idéntico devuelve la orden ya registrada.
CREATE OR REPLACE FUNCTION prod_preparar(p_datos JSONB,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE pr pro_producto%ROWTYPE; rec pro_receta%ROWTYPE; pd ven_pedido_detalle%ROWTYPE;
  orden prod_orden%ROWTYPE; pedido ven_pedido%ROWTYPE; ins RECORD; partes JSONB:='[]'; salida BIGINT;
  v_cantidad NUMERIC:=(p_datos->>'cantidad')::NUMERIC; costo NUMERIC; suc BIGINT; almacen BIGINT:=(p_datos->>'id_almacen_destino')::BIGINT;
  item BIGINT:=(p_datos->>'id_pedido_detalle')::BIGINT; receta BIGINT:=(p_datos->>'id_receta')::BIGINT;
BEGIN
  IF item IS NOT NULL THEN
    SELECT id_pedido INTO suc FROM ven_pedido_detalle WHERE id=item;
    pedido:=ven_bloquear_pedido(suc);
    SELECT * INTO pd FROM ven_pedido_detalle WHERE id=item FOR UPDATE;
  END IF;
  PERFORM alm_bloquear();
  SELECT * INTO orden FROM prod_orden WHERE codigo=p_datos->>'codigo';
  IF FOUND THEN
    IF orden.id_pedido_detalle IS DISTINCT FROM item OR orden.id_almacen_destino IS DISTINCT FROM almacen OR
      NOT EXISTS(SELECT 1 FROM prod_orden_detalle WHERE id_orden=orden.id AND id_receta=receta AND prod_orden_detalle.cantidad=v_cantidad) THEN
      RAISE EXCEPTION 'Código de producción utilizado con otros datos'; END IF;
    RETURN json_build_object('registro',to_jsonb(orden));
  END IF;
  IF v_cantidad IS NULL OR v_cantidad<=0 OR v_cantidad<>round(v_cantidad,4) THEN RAISE EXCEPTION 'Cantidad de producción inválida'; END IF;
  SELECT * INTO rec FROM pro_receta WHERE id=receta AND estado=1;
  IF NOT FOUND OR rec.rendimiento_porciones<=0 THEN RAISE EXCEPTION 'Receta inválida'; END IF;
  SELECT * INTO pr FROM pro_producto WHERE id=rec.id_producto AND estado=1 AND controla_stock;
  IF NOT FOUND THEN RAISE EXCEPTION 'El producto terminado debe estar activo y controlar stock'; END IF;
  SELECT id_sucursal INTO suc FROM gen_almacen WHERE id=almacen AND estado=1;
  IF suc IS NULL THEN RAISE EXCEPTION 'Almacén destino inválido'; END IF;
  IF item IS NOT NULL THEN
    IF pd.id_producto<>pr.id OR pd.id_receta IS DISTINCT FROM rec.id OR pd.tipo_linea=3 OR pd.estado<>1
      OR pd.id_comanda IS NULL OR pedido.estado_pedido<>2 OR pedido.id_sucursal<>suc THEN RAISE EXCEPTION 'Detalle no disponible para preparación'; END IF;
    IF almacen IS DISTINCT FROM COALESCE(pd.id_almacen_reserva,pr.id_almacen_stock) THEN RAISE EXCEPTION 'Use el almacén de reserva del pedido'; END IF;
    PERFORM ven_reservar_item(item,p_usuario);
    SELECT * INTO pd FROM ven_pedido_detalle WHERE id=item;
    IF v_cantidad>pd.cantidad-pd.cantidad_cancelada-pd.cantidad_entregada-pd.cantidad_reservada THEN RAISE EXCEPTION 'La preparación excede lo pendiente'; END IF;
    -- Lo apartado al comandar se libera para consumirlo en esta misma transacción.
    PERFORM ven_liberar_insumos(item,v_cantidad,p_usuario);
    FOR ins IN SELECT * FROM ven_consumos_item(item) LOOP
      IF ins.id_producto=pr.id THEN RAISE EXCEPTION 'El plato no puede ser insumo de sí mismo'; END IF;
      partes:=partes||jsonb_build_array(jsonb_build_object('id_producto',ins.id_producto,'id_almacen',ins.id_almacen,
        'id_unidad_medida',ins.id_unidad_medida,'cantidad',round(ins.cantidad*v_cantidad/pd.cantidad,4),'signo',-1));
    END LOOP;
  ELSE
    IF EXISTS(SELECT 1 FROM pro_receta_insumo WHERE id_receta=rec.id AND estado=1 AND grupo_sustitucion IS NOT NULL) THEN
      RAISE EXCEPTION 'La producción anticipada requiere una receta sin grupos de sustitución; utilice preparación por pedido'; END IF;
    FOR ins IN SELECT ri.*,p.id_unidad_medida AS unidad_base,p.id_almacen_stock,a.id_sucursal,p.controla_stock,p.estado AS estado_producto
      FROM pro_receta_insumo ri JOIN pro_producto p ON p.id=ri.id_producto_insumo LEFT JOIN gen_almacen a ON a.id=p.id_almacen_stock
      WHERE ri.id_receta=rec.id AND ri.estado=1 AND NOT ri.es_opcional
    LOOP
      IF ins.id_producto_insumo=pr.id OR ins.id_sucursal IS DISTINCT FROM suc OR NOT ins.controla_stock OR ins.estado_producto<>1 THEN
        RAISE EXCEPTION 'Insumo inválido o de otra sucursal'; END IF;
      partes:=partes||jsonb_build_array(jsonb_build_object('id_producto',ins.id_producto_insumo,'id_almacen',ins.id_almacen_stock,
        'id_unidad_medida',ins.unidad_base,'cantidad',round(ins.cantidad*v_cantidad/rec.rendimiento_porciones*(1+ins.porcentaje_merma/100)
          *ven_factor_unidad(ins.id_unidad_medida,ins.unidad_base),4),'signo',-1));
    END LOOP;
  END IF;
  IF jsonb_array_length(partes)=0 THEN RAISE EXCEPTION 'La receta no tiene consumos'; END IF;
  INSERT INTO prod_orden(id_sucursal,id_almacen_destino,codigo,tipo_produccion,tipo_preparacion,id_pedido_detalle,estado_orden,observacion,id_usuario_creacion,id_usuario_modificacion)
    VALUES(suc,almacen,p_datos->>'codigo',1,CASE WHEN item IS NULL THEN 'ANTICIPADA' ELSE 'POR_PEDIDO' END,item,2,p_datos->>'observacion',p_usuario,p_usuario)
    RETURNING * INTO orden;
  salida:=alm_aplicar('PROD-S-'||orden.id,'SALIDA','PRODUCCION_CONSUMO','PRODUCCION',orden.id,partes,p_usuario);
  SELECT round(sum(md.cantidad*md.costo_unitario)/v_cantidad,4) INTO costo FROM alm_movimiento_detalle md WHERE id_movimiento=salida;
  PERFORM alm_aplicar('PROD-E-'||orden.id,'ENTRADA','PRODUCCION_ENTRADA','PRODUCCION',orden.id,
    jsonb_build_array(jsonb_build_object('id_producto',pr.id,'id_almacen',almacen,'id_unidad_medida',pr.id_unidad_medida,
      'cantidad',v_cantidad,'signo',1,'costo_unitario',costo)),p_usuario);
  INSERT INTO prod_orden_detalle(id_orden,id_producto,id_receta,cantidad,id_unidad_medida,costo_unitario,id_usuario_creacion,id_usuario_modificacion)
    VALUES(orden.id,pr.id,rec.id,v_cantidad,pr.id_unidad_medida,costo,p_usuario,p_usuario);
  IF item IS NOT NULL THEN
    UPDATE alm_producto_stock SET stock_reservado=stock_reservado+v_cantidad,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
      WHERE id_producto=pr.id AND id_almacen=almacen;
    UPDATE ven_pedido_detalle SET cantidad_reservada=cantidad_reservada+v_cantidad,id_almacen_reserva=almacen,
      estado_preparacion=CASE WHEN cantidad_reservada+v_cantidad+cantidad_entregada+cantidad_cancelada=ven_pedido_detalle.cantidad THEN 4 ELSE 3 END,
      id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=item;
  END IF;
  RETURN json_build_object('registro',to_jsonb(orden));
END $$;
