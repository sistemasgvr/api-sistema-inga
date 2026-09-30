CREATE OR REPLACE FUNCTION alm_confirmar(p_id BIGINT,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE m alm_movimiento%ROWTYPE; d RECORD; s alm_producto_stock%ROWTYPE; t TEXT; motivo_tipo INTEGER; tipo_valor INTEGER;
BEGIN
  PERFORM alm_bloquear();
  SELECT * INTO m FROM alm_movimiento WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Movimiento no encontrado' USING ERRCODE='P0002'; END IF;
  IF m.estado=2 THEN RETURN json_build_object('registro',to_jsonb(m)); END IF;
  IF m.estado<>1 THEN RAISE EXCEPTION 'Movimiento cancelado'; END IF;
  SELECT o.codigo,o.valor_entero INTO t,tipo_valor FROM gen_lista_opcion o JOIN gen_lista l ON l.id=o.id_lista
    WHERE o.id=m.id_tipo_movimiento AND l.codigo='ALM_TIPO_MOVIMIENTO' AND l.estado=1 AND o.estado=1;
  SELECT o.valor_entero INTO motivo_tipo FROM gen_lista_opcion o JOIN gen_lista l ON l.id=o.id_lista
    WHERE o.id=m.id_motivo_movimiento AND l.codigo='ALM_MOTIVO_MOVIMIENTO' AND l.estado=1 AND o.estado=1;
  IF t IS NULL OR motivo_tipo IS NULL OR tipo_valor IS DISTINCT FROM motivo_tipo THEN RAISE EXCEPTION 'Tipo y motivo incompatibles'; END IF;
  IF NOT EXISTS(SELECT 1 FROM alm_movimiento_detalle WHERE id_movimiento=p_id) THEN RAISE EXCEPTION 'Movimiento sin detalles'; END IF;
  IF EXISTS(SELECT 1 FROM alm_movimiento_detalle WHERE id_movimiento=p_id AND
    ((t='ENTRADA' AND signo<>1) OR (t='SALIDA' AND signo<>-1))) THEN RAISE EXCEPTION 'Signo incompatible con el tipo'; END IF;
  IF t='TRASLADO' AND EXISTS(SELECT 1 FROM alm_movimiento_detalle WHERE id_movimiento=p_id GROUP BY id_producto
    HAVING count(*)<>2 OR count(DISTINCT id_almacen)<>2 OR sum(cantidad*signo)<>0 OR min(signo)<>-1 OR max(signo)<>1)
    THEN RAISE EXCEPTION 'Traslado requiere una salida y una entrada iguales por producto en almacenes distintos'; END IF;
  FOR d IN SELECT md.*,pr.id_unidad_medida AS unidad_base,pr.controla_stock,pr.estado AS producto_estado,a.estado AS almacen_estado
    FROM alm_movimiento_detalle md JOIN pro_producto pr ON pr.id=md.id_producto JOIN gen_almacen a ON a.id=md.id_almacen
    WHERE md.id_movimiento=p_id ORDER BY md.signo,md.id_almacen,md.id_producto,md.numero_linea
  LOOP
    IF NOT d.controla_stock OR d.producto_estado<>1 OR d.almacen_estado<>1 OR d.id_unidad_medida<>d.unidad_base THEN
      RAISE EXCEPTION 'Producto/almacén inactivo, sin control de stock o unidad diferente a la base'; END IF;
    INSERT INTO alm_producto_stock(id_producto,id_almacen,id_usuario_creacion)
      VALUES(d.id_producto,d.id_almacen,p_usuario) ON CONFLICT(id_almacen,id_producto) DO NOTHING;
    SELECT * INTO STRICT s FROM alm_producto_stock WHERE id_producto=d.id_producto AND id_almacen=d.id_almacen FOR UPDATE;
    IF s.estado<>1 THEN RAISE EXCEPTION 'Registro de stock inactivo'; END IF;
    IF d.signo=-1 AND s.stock_actual-s.stock_reservado<d.cantidad THEN RAISE EXCEPTION 'Stock disponible insuficiente del producto %',d.id_producto; END IF;
    IF d.signo=-1 THEN d.costo_unitario:=s.costo_promedio;
    ELSIF t='TRASLADO' THEN
      SELECT costo_unitario INTO d.costo_unitario FROM alm_movimiento_detalle WHERE id_movimiento=p_id AND id_producto=d.id_producto AND signo=-1;
    END IF;
    IF d.costo_unitario IS NULL THEN RAISE EXCEPTION 'Las entradas requieren costo unitario'; END IF;
    UPDATE alm_movimiento_detalle SET stock_anterior=s.stock_actual,stock_nuevo=s.stock_actual+d.cantidad*d.signo,
      costo_unitario=d.costo_unitario,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=d.id;
    UPDATE alm_producto_stock SET stock_actual=s.stock_actual+d.cantidad*d.signo,
      costo_promedio=CASE WHEN d.signo=1 THEN round((s.stock_actual*s.costo_promedio+d.cantidad*d.costo_unitario)/(s.stock_actual+d.cantidad),4) ELSE s.costo_promedio END,
      id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=s.id;
  END LOOP;
  UPDATE alm_movimiento SET estado=2,fecha_confirmacion=CURRENT_TIMESTAMP,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
    WHERE id=p_id RETURNING * INTO m;
  RETURN json_build_object('registro',to_jsonb(m));
END $$;
