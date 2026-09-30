CREATE OR REPLACE FUNCTION public.ven_pedido_comandar(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; d RECORD;
  v_pendientes JSONB := '[]'::JSONB;
  v_comanda BIGINT; v_numero INTEGER; v_estacion BIGINT;
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
    -- Validación sin consumo: los ingredientes se descuentan al producir.
    PERFORM * FROM ven_consumos_item(d.id);
    v_pendientes := v_pendientes || jsonb_build_array(jsonb_build_object('id',d.id,'id_estacion',d.id_estacion));
  END LOOP;
  -- Reintentar sin nuevos ítems no vuelve a descontar ni genera otra comanda.
  IF jsonb_array_length(v_pendientes) = 0 THEN
    IF v.estado_pedido = 1 THEN RAISE EXCEPTION 'El pedido no tiene ítems pendientes para comandar'; END IF;
    RETURN ven_obtener_pedido(p_id);
  END IF;
  FOR v_estacion IN SELECT DISTINCT x.id_estacion FROM jsonb_to_recordset(v_pendientes) AS x(id BIGINT,id_estacion BIGINT) ORDER BY x.id_estacion LOOP
    SELECT COALESCE(max(numero),0)+1 INTO v_numero FROM ven_comanda WHERE id_pedido = p_id AND id_estacion = v_estacion;
    INSERT INTO ven_comanda(id_pedido,id_estacion,numero,id_usuario_creacion,id_usuario_modificacion)
      VALUES(p_id,v_estacion,v_numero,p_usuario,p_usuario) RETURNING id INTO v_comanda;
    UPDATE ven_pedido_detalle SET id_comanda = v_comanda,estado_preparacion = 2,stock_descontado = FALSE,
      id_usuario_modificacion = p_usuario,fecha_modificacion = CURRENT_TIMESTAMP
      WHERE id IN (SELECT x.id FROM jsonb_to_recordset(v_pendientes) AS x(id BIGINT,id_estacion BIGINT) WHERE x.id_estacion = v_estacion);
  END LOOP;
  FOR d IN SELECT x.id FROM jsonb_to_recordset(v_pendientes) AS x(id BIGINT,id_estacion BIGINT) ORDER BY x.id LOOP
    PERFORM ven_reservar_item(d.id,p_usuario);
  END LOOP;
  UPDATE ven_pedido SET estado_pedido = 2 WHERE id = p_id;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  RETURN ven_obtener_pedido(p_id);
END;
$$;
