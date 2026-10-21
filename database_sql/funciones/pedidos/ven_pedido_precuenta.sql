CREATE OR REPLACE FUNCTION ven_pedido_precuenta(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; estacion gen_estacion%ROWTYPE; comanda BIGINT; numero INTEGER;
BEGIN
  v:=ven_bloquear_pedido(p_id);
  IF v.estado_pedido NOT IN (1,2,3) THEN RAISE EXCEPTION 'El pedido no admite precuenta'; END IF;
  SELECT * INTO estacion FROM gen_estacion WHERE es_caja_principal AND id_sucursal=v.id_sucursal AND estado=1;
  IF NOT FOUND OR NULLIF(btrim(estacion.impresora_ip),'') IS NULL THEN RAISE EXCEPTION 'Configure la estación principal de caja y cobros en Estaciones'; END IF;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  SELECT * INTO v FROM ven_pedido WHERE id=p_id;
  IF v.monto_total<=0 THEN RAISE EXCEPTION 'El pedido no tiene consumos'; END IF;
  -- Evita que un doble clic en «Precuenta» encole el mismo ticket dos veces. Si
  -- aún no se imprimió, se actualiza con los consumos de ahora (platos añadidos
  -- o cancelados después) y se descarta el PDF archivado.
  UPDATE ven_impresion_trabajo t SET contenido=t.contenido || ven_contenido_precuenta(p_id),ruta_pdf=NULL,actualizado=CURRENT_TIMESTAMP
    FROM ven_comanda c WHERE c.id=t.id_comanda AND c.id_pedido=p_id AND t.estado='pendiente' AND t.contenido->>'tipo'='PRECUENTA';
  IF FOUND OR EXISTS (SELECT 1 FROM ven_impresion_trabajo t JOIN ven_comanda c ON c.id=t.id_comanda
             WHERE c.id_pedido=p_id AND t.estado='procesando' AND t.contenido->>'tipo'='PRECUENTA') THEN
    RETURN ven_obtener_pedido(p_id);
  END IF;
  UPDATE ven_pedido SET estado_pedido=3,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=p_id;
  UPDATE ven_mesa SET estado_mesa=3 WHERE id=v.id_mesa;
  SELECT COALESCE(max(c.numero),0)+1 INTO numero FROM ven_comanda c WHERE c.id_pedido=p_id;
  INSERT INTO ven_comanda(id_pedido,id_estacion,numero,id_usuario_creacion,id_usuario_modificacion)
    VALUES(p_id,estacion.id,numero,p_usuario,p_usuario) RETURNING id INTO comanda;
  INSERT INTO ven_impresion_trabajo(id_comanda,id_estacion,contenido)
    VALUES(comanda,estacion.id,jsonb_build_object('tipo','PRECUENTA','id',comanda::TEXT,'numero',numero,'estacion',estacion.nombre)
      || ven_contenido_precuenta(p_id));
  RETURN ven_obtener_pedido(p_id);
END $$;
