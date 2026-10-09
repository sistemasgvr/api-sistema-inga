-- Libera los ingredientes apartados para p_unidades de la línea que aún no tienen plato preparado.
-- Llamar ANTES de modificar cantidad_reservada/cancelada/entregada: la proporción usa lo pendiente actual.
-- Devuelve lo liberado (formato de detalle de alm_aplicar) para consumirlo o registrarlo como merma.
CREATE OR REPLACE FUNCTION ven_liberar_insumos(p_item BIGINT,p_unidades NUMERIC,p_usuario BIGINT) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE d ven_pedido_detalle%ROWTYPE; pendientes NUMERIC; r RECORD; liberar NUMERIC; liberados JSONB:='[]';
BEGIN
  SELECT * INTO STRICT d FROM ven_pedido_detalle WHERE id=p_item;
  pendientes:=d.cantidad-d.cantidad_cancelada-d.cantidad_entregada-d.cantidad_reservada;
  IF p_unidades IS NULL OR p_unidades<=0 OR pendientes<=0 THEN RETURN liberados; END IF;
  FOR r IN SELECT ri.*,p.id_unidad_medida FROM ven_pedido_reserva_insumo ri JOIN pro_producto p ON p.id=ri.id_producto
    WHERE ri.id_pedido_detalle=p_item AND ri.cantidad>0 ORDER BY ri.id_almacen,ri.id_producto FOR UPDATE OF ri
  LOOP
    -- Al cubrir todo lo pendiente se libera el saldo exacto, sin residuos de redondeo.
    liberar:=CASE WHEN p_unidades>=pendientes THEN r.cantidad ELSE LEAST(r.cantidad,round(r.cantidad*p_unidades/pendientes,4)) END;
    CONTINUE WHEN liberar<=0;
    UPDATE alm_producto_stock SET stock_reservado=stock_reservado-liberar,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
      WHERE id_producto=r.id_producto AND id_almacen=r.id_almacen;
    UPDATE ven_pedido_reserva_insumo SET cantidad=cantidad-liberar,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
      WHERE id=r.id;
    liberados:=liberados||jsonb_build_array(jsonb_build_object('id_producto',r.id_producto,'id_almacen',r.id_almacen,
      'id_unidad_medida',r.id_unidad_medida,'cantidad',liberar,'signo',-1));
  END LOOP;
  RETURN liberados;
END $$;
