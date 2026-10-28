-- Contenido del ticket de un comprobante, con el mismo formato que la cola de impresión.
-- Lo usan el papel y el PDF archivado, para que ambos muestren lo mismo.
DROP FUNCTION IF EXISTS ven_ticket_comprobante(p_id_comprobante BIGINT);
CREATE OR REPLACE FUNCTION ven_ticket_comprobante(p_id_comprobante BIGINT)
RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE cp ven_comprobante%ROWTYPE; pedido ven_pedido%ROWTYPE; detalle JSONB;
BEGIN
  SELECT * INTO cp FROM ven_comprobante WHERE id = p_id_comprobante;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT * INTO pedido FROM ven_pedido WHERE id = cp.id_pedido;
  detalle := (ven_obtener_pedido(pedido.id)::JSONB)->'registro';
  RETURN jsonb_build_object(
    'tipo', 'COMPROBANTE', 'id', cp.id::TEXT, 'numero', 1, 'pedido', pedido.codigo,
    'mesa', detalle->>'codigo_mesa', 'mozo', detalle->>'nombre_mozo', 'tipo_pedido', pedido.tipo_pedido,
    'fecha', cp.fecha_emision, 'estacion', 'CAJA', 'total', cp.monto_total,
    'comprobante', jsonb_build_object(
      'tipo_comprobante', cp.tipo_comprobante,
      'nombre_tipo', CASE cp.tipo_comprobante WHEN 1 THEN 'BOLETA DE VENTA' WHEN 2 THEN 'FACTURA' ELSE 'NOTA DE VENTA' END,
      'numero', cp.serie || '-' || cp.correlativo,
      'receptor_tipo_doc', cp.receptor_tipo_doc,
      'receptor_num_doc', cp.receptor_num_doc, 'receptor_razon_social', cp.receptor_razon_social,
      'monto_gravado', cp.monto_gravado, 'monto_exonerado', cp.monto_exonerado,
      'monto_igv', cp.monto_igv, 'monto_total', cp.monto_total,
      -- Para el QR de la representación impresa (boleta/factura electrónica).
      'fecha_emision', to_char(cp.fecha_emision AT TIME ZONE 'America/Lima', 'YYYY-MM-DD'),
      'hash', cp.hash_qr),
    'pagos', COALESCE((SELECT jsonb_agg(jsonb_build_object('nombre_medio', COALESCE(o.nombre, g.medio_pago::TEXT), 'monto', g.monto)
        ORDER BY g.id)
      FROM ven_pago g
      LEFT JOIN gen_lista l ON l.codigo = 'MEDIO_PAGO'
      LEFT JOIN gen_lista_opcion o ON o.id_lista = l.id AND o.valor_entero = g.medio_pago
      WHERE g.id_pedido = pedido.id AND g.estado = 1), '[]'::JSONB),
    'items', COALESCE((SELECT jsonb_agg(jsonb_build_object('cantidad', d.cantidad, 'nombre_producto', d.descripcion,
        'monto_subtotal', d.monto_total) ORDER BY d.id)
      FROM ven_comprobante_detalle d WHERE d.id_comprobante = cp.id AND d.estado = 1), '[]'::JSONB));
END;
$$;
