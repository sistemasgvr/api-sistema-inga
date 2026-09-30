CREATE OR REPLACE FUNCTION alm_registrar(p_datos JSONB,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE mov BIGINT; x JSONB; n INTEGER:=0;
BEGIN
  PERFORM alm_bloquear();
  INSERT INTO alm_movimiento(codigo,id_tipo_movimiento,id_motivo_movimiento,documento_tipo,documento_id,id_movimiento_referencia,observacion,id_usuario_creacion)
  VALUES(p_datos->>'codigo',(p_datos->>'id_tipo_movimiento')::BIGINT,(p_datos->>'id_motivo_movimiento')::BIGINT,
    p_datos->>'documento_tipo',(p_datos->>'documento_id')::BIGINT,(p_datos->>'id_movimiento_referencia')::BIGINT,p_datos->>'observacion',p_usuario) RETURNING id INTO mov;
  IF jsonb_typeof(p_datos->'detalles') IS DISTINCT FROM 'array' OR jsonb_array_length(p_datos->'detalles')=0 THEN RAISE EXCEPTION 'Debe registrar detalles'; END IF;
  FOR x IN SELECT * FROM jsonb_array_elements(p_datos->'detalles') LOOP
    n:=n+1;
    INSERT INTO alm_movimiento_detalle(id_movimiento,numero_linea,id_producto,id_almacen,id_unidad_medida,cantidad,signo,costo_unitario,observacion,id_usuario_creacion)
    VALUES(mov,n,(x->>'id_producto')::BIGINT,(x->>'id_almacen')::BIGINT,(x->>'id_unidad_medida')::BIGINT,
      (x->>'cantidad')::NUMERIC,(x->>'signo')::SMALLINT,(x->>'costo_unitario')::NUMERIC,x->>'observacion',p_usuario);
  END LOOP;
  IF COALESCE((p_datos->>'confirmar')::BOOLEAN,FALSE) THEN RETURN alm_confirmar(mov,p_usuario); END IF;
  RETURN json_build_object('registro',(SELECT to_jsonb(m) FROM alm_movimiento m WHERE id=mov));
END $$;

-- Uso interno de producción y pedidos, con códigos del catálogo, nunca IDs fijos.
