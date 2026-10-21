-- Imprime un comprobante en la estación principal de caja, por la misma cola que las comandas.
DROP FUNCTION IF EXISTS ven_imprimir_comprobante(p_id_comprobante BIGINT, p_usuario BIGINT);
CREATE OR REPLACE FUNCTION ven_imprimir_comprobante(p_id_comprobante BIGINT, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE cp ven_comprobante%ROWTYPE; pedido ven_pedido%ROWTYPE; estacion gen_estacion%ROWTYPE;
  comanda BIGINT; numero INTEGER;
BEGIN
  SELECT * INTO cp FROM ven_comprobante WHERE id = p_id_comprobante;
  IF NOT FOUND THEN RAISE EXCEPTION 'El comprobante no existe' USING ERRCODE = 'P0002'; END IF;
  IF cp.estado <> 1 THEN RAISE EXCEPTION 'El comprobante está anulado; imprime el vigente'; END IF;

  SELECT * INTO pedido FROM ven_pedido WHERE id = cp.id_pedido FOR UPDATE;
  SELECT * INTO estacion FROM gen_estacion WHERE es_caja_principal AND id_sucursal = pedido.id_sucursal AND estado = 1;
  IF NOT FOUND OR NULLIF(btrim(estacion.impresora_ip), '') IS NULL THEN
    RAISE EXCEPTION 'Configure la estación principal de caja y cobros en Estaciones';
  END IF;

  -- Un doble clic en «Imprimir» no debe duplicar el mismo ticket en la cola.
  IF EXISTS (
    SELECT 1 FROM ven_impresion_trabajo t
    JOIN ven_comanda c ON c.id = t.id_comanda
    WHERE c.id_pedido = pedido.id
      AND t.estado IN ('pendiente', 'procesando')
      AND t.contenido->>'tipo' = 'COMPROBANTE'
      AND t.contenido->'comprobante'->>'numero' = cp.serie || '-' || cp.correlativo
  ) THEN
    RETURN ven_obtener_venta(pedido.id);
  END IF;

  SELECT COALESCE(max(c.numero), 0) + 1 INTO numero FROM ven_comanda c WHERE c.id_pedido = pedido.id;
  INSERT INTO ven_comanda(id_pedido, id_estacion, numero, id_usuario_creacion, id_usuario_modificacion)
    VALUES(pedido.id, estacion.id, numero, p_usuario, p_usuario) RETURNING id INTO comanda;

  -- El contenido sale de ven_ticket_comprobante: el papel y el PDF archivado son iguales.
  INSERT INTO ven_impresion_trabajo(id_comanda, id_estacion, contenido)
  VALUES(comanda, estacion.id, ven_ticket_comprobante(cp.id)
    || jsonb_build_object('id', comanda::TEXT, 'numero', numero, 'estacion', estacion.nombre));

  RETURN ven_obtener_venta(pedido.id);
END;
$$;
