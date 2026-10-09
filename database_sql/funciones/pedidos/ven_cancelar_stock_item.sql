-- Cancelación acumulada de unidades no entregadas. Primero cancela las unidades sin plato preparado
-- (libera sus ingredientes apartados o, si la preparación ya inició, puede registrarlos como merma);
-- después las preparadas, que se conservan disponibles o se dan de baja por merma.
CREATE OR REPLACE FUNCTION ven_cancelar_stock_item(p_item BIGINT,p_objetivo NUMERIC,p_destino TEXT,p_destino_insumos TEXT,p_usuario BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE d ven_pedido_detalle%ROWTYPE; pr pro_producto%ROWTYPE; n NUMERIC; sin_preparar NUMERIC; preparados NUMERIC; insumos JSONB;
BEGIN
  PERFORM alm_bloquear();
  SELECT * INTO STRICT d FROM ven_pedido_detalle WHERE id=p_item FOR UPDATE;
  IF p_objetivo IS NULL OR p_objetivo<d.cantidad_cancelada OR p_objetivo>d.cantidad-d.cantidad_entregada OR p_objetivo<>round(p_objetivo,4) THEN
    RAISE EXCEPTION 'Cantidad cancelada inválida; no se cancelan unidades entregadas por este flujo'; END IF;
  n:=p_objetivo-d.cantidad_cancelada;
  IF n=0 THEN RETURN; END IF;
  sin_preparar:=LEAST(n,GREATEST(d.cantidad-d.cantidad_cancelada-d.cantidad_entregada-d.cantidad_reservada,0));
  preparados:=n-sin_preparar;
  IF sin_preparar>0 THEN
    IF d.estado_preparacion=3 AND EXISTS(SELECT 1 FROM ven_pedido_reserva_insumo WHERE id_pedido_detalle=d.id AND cantidad>0)
      AND (p_destino_insumos IS NULL OR p_destino_insumos NOT IN ('LIBERAR','MERMA')) THEN
      RAISE EXCEPTION 'La preparación ya inició: indique destino_insumos LIBERAR o MERMA'; END IF;
    insumos:=ven_liberar_insumos(d.id,sin_preparar,p_usuario);
    IF d.estado_preparacion=3 AND p_destino_insumos='MERMA' AND jsonb_array_length(insumos)>0 THEN
      PERFORM alm_aplicar('MERMA-INS-'||d.id||'-'||p_objetivo,'SALIDA','MERMA','PEDIDO_DETALLE',d.id,insumos,p_usuario);
    END IF;
  END IF;
  IF preparados>0 THEN
    IF p_destino IS NULL OR p_destino NOT IN ('DISPONIBLE','MERMA') THEN RAISE EXCEPTION 'Indique destino_preparado: DISPONIBLE o MERMA'; END IF;
    IF p_destino='DISPONIBLE' AND d.id_receta IS NOT NULL AND (cardinality(d.insumos_seleccionados)>0 OR EXISTS(
      SELECT 1 FROM ven_pedido_detalle_adicional da JOIN pro_adicional a ON a.id=da.id_adicional
      WHERE da.id_pedido_detalle=d.id AND da.estado=1 AND a.id_producto_insumo IS NOT NULL)) THEN
      RAISE EXCEPTION 'Una preparación personalizada no se libera como plato estándar; registre MERMA'; END IF;
    UPDATE alm_producto_stock SET stock_reservado=stock_reservado-preparados,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
      WHERE id_producto=d.id_producto AND id_almacen=d.id_almacen_reserva;
    IF p_destino='MERMA' THEN
      SELECT * INTO STRICT pr FROM pro_producto WHERE id=d.id_producto;
      PERFORM alm_aplicar('MERMA-PED-'||d.id||'-'||p_objetivo,'SALIDA','MERMA','PEDIDO_DETALLE',d.id,
        jsonb_build_array(jsonb_build_object('id_producto',d.id_producto,'id_almacen',d.id_almacen_reserva,
          'id_unidad_medida',pr.id_unidad_medida,'cantidad',preparados,'signo',-1)),p_usuario);
    END IF;
  END IF;
  UPDATE ven_pedido_detalle SET cantidad_cancelada=p_objetivo,cantidad_reservada=cantidad_reservada-preparados,
    tipo_linea=CASE WHEN p_objetivo=cantidad THEN 3 ELSE tipo_linea END,
    estado_preparacion=CASE WHEN p_objetivo=cantidad THEN 6 ELSE estado_preparacion END,
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=d.id;
END $$;
