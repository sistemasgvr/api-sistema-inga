CREATE OR REPLACE FUNCTION ven_pedido_precuenta(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; estacion gen_estacion%ROWTYPE; comanda BIGINT; numero INTEGER; detalle JSONB;
BEGIN
  v:=ven_bloquear_pedido(p_id);
  IF v.estado_pedido NOT IN (1,2,3) THEN RAISE EXCEPTION 'El pedido no admite precuenta'; END IF;
  SELECT * INTO estacion FROM gen_estacion WHERE es_caja_principal AND id_sucursal=v.id_sucursal AND estado=1;
  IF NOT FOUND OR NULLIF(btrim(estacion.impresora_ip),'') IS NULL THEN RAISE EXCEPTION 'Configure la estación principal de caja y cobros en Estaciones'; END IF;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  SELECT * INTO v FROM ven_pedido WHERE id=p_id;
  IF v.monto_total<=0 THEN RAISE EXCEPTION 'El pedido no tiene consumos'; END IF;
  UPDATE ven_pedido SET estado_pedido=3,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=p_id;
  UPDATE ven_mesa SET estado_mesa=3 WHERE id=v.id_mesa;
  SELECT COALESCE(max(c.numero),0)+1 INTO numero FROM ven_comanda c WHERE c.id_pedido=p_id;
  INSERT INTO ven_comanda(id_pedido,id_estacion,numero,id_usuario_creacion,id_usuario_modificacion)
    VALUES(p_id,estacion.id,numero,p_usuario,p_usuario) RETURNING id INTO comanda;
  detalle:=(ven_obtener_pedido(p_id)::JSONB)->'registro';
  INSERT INTO ven_impresion_trabajo(id_comanda,id_estacion,contenido)
    VALUES(comanda,estacion.id,jsonb_build_object('tipo','PRECUENTA','id',comanda::TEXT,'numero',numero,'pedido',v.codigo,
      'mesa',detalle->>'codigo_mesa','mozo',detalle->>'nombre_mozo','tipo_pedido',v.tipo_pedido,'fecha',CURRENT_TIMESTAMP,
      'estacion',estacion.nombre,'total',v.monto_total,'items',COALESCE((SELECT jsonb_agg(x || jsonb_build_object('cantidad',
        (x->>'cantidad')::NUMERIC-COALESCE((x->>'cantidad_cancelada')::NUMERIC,0))) FROM jsonb_array_elements(detalle->'items') x
        WHERE (x->>'tipo_linea')::INTEGER<>3 AND (x->>'cantidad')::NUMERIC>COALESCE((x->>'cantidad_cancelada')::NUMERIC,0)),'[]'::JSONB)));
  RETURN ven_obtener_pedido(p_id);
END $$;
