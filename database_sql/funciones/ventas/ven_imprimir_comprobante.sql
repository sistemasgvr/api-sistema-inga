-- Imprime un comprobante en la estación principal de caja, por la misma cola
-- que las comandas. Sigue el patrón de ven_pedido_precuenta: registra una
-- comanda sin ítems solo para identificar el trabajo de impresión, y el ticket
-- se arma con el tipo 'COMPROBANTE' (ver formatearComanda en el front).
CREATE OR REPLACE FUNCTION ven_imprimir_comprobante(p_id_comprobante BIGINT, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE cp ven_comprobante%ROWTYPE; pedido ven_pedido%ROWTYPE; estacion gen_estacion%ROWTYPE;
  comanda BIGINT; numero INTEGER; detalle JSONB;
BEGIN
  SELECT * INTO cp FROM ven_comprobante WHERE id = p_id_comprobante;
  IF NOT FOUND THEN RAISE EXCEPTION 'El comprobante no existe' USING ERRCODE = 'P0002'; END IF;
  IF cp.estado <> 1 THEN RAISE EXCEPTION 'El comprobante está anulado; imprime el vigente'; END IF;

  SELECT * INTO pedido FROM ven_pedido WHERE id = cp.id_pedido FOR UPDATE;
  SELECT * INTO estacion FROM gen_estacion WHERE es_caja_principal AND id_sucursal = pedido.id_sucursal AND estado = 1;
  IF NOT FOUND OR NULLIF(btrim(estacion.impresora_ip), '') IS NULL THEN
    RAISE EXCEPTION 'Configure la estación principal de caja y cobros en Estaciones';
  END IF;

  SELECT COALESCE(max(c.numero), 0) + 1 INTO numero FROM ven_comanda c WHERE c.id_pedido = pedido.id;
  INSERT INTO ven_comanda(id_pedido, id_estacion, numero, id_usuario_creacion, id_usuario_modificacion)
    VALUES(pedido.id, estacion.id, numero, p_usuario, p_usuario) RETURNING id INTO comanda;

  detalle := (ven_obtener_pedido(pedido.id)::JSONB)->'registro';
  INSERT INTO ven_impresion_trabajo(id_comanda, id_estacion, contenido)
  VALUES(comanda, estacion.id, jsonb_build_object(
    'tipo', 'COMPROBANTE', 'id', comanda::TEXT, 'numero', numero, 'pedido', pedido.codigo,
    'mesa', detalle->>'codigo_mesa', 'mozo', detalle->>'nombre_mozo', 'tipo_pedido', pedido.tipo_pedido,
    'fecha', cp.fecha_emision, 'estacion', estacion.nombre, 'total', cp.monto_total,
    'comprobante', jsonb_build_object(
      'tipo_comprobante', cp.tipo_comprobante,
      'nombre_tipo', CASE cp.tipo_comprobante WHEN 1 THEN 'BOLETA DE VENTA' WHEN 2 THEN 'FACTURA' ELSE 'NOTA DE VENTA' END,
      'numero', cp.serie || '-' || cp.correlativo,
      'receptor_num_doc', cp.receptor_num_doc, 'receptor_razon_social', cp.receptor_razon_social,
      'monto_gravado', cp.monto_gravado, 'monto_igv', cp.monto_igv, 'monto_total', cp.monto_total),
    'pagos', COALESCE((SELECT jsonb_agg(jsonb_build_object('nombre_medio', COALESCE(o.nombre, g.medio_pago::TEXT), 'monto', g.monto)
        ORDER BY g.id)
      FROM ven_pago g
      LEFT JOIN gen_lista l ON l.codigo = 'MEDIO_PAGO'
      LEFT JOIN gen_lista_opcion o ON o.id_lista = l.id AND o.valor_entero = g.medio_pago
      WHERE g.id_pedido = pedido.id AND g.estado = 1), '[]'::JSONB),
    'items', COALESCE((SELECT jsonb_agg(jsonb_build_object('cantidad', d.cantidad, 'nombre_producto', d.descripcion,
        'monto_subtotal', d.monto_total) ORDER BY d.id)
      FROM ven_comprobante_detalle d WHERE d.id_comprobante = cp.id AND d.estado = 1), '[]'::JSONB)));

  RETURN ven_obtener_venta(pedido.id);
END;
$$;
