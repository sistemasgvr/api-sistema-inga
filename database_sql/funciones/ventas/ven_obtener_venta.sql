-- Detalle de una venta: el pedido (ven_obtener_pedido) más sus pagos con la
-- caja y el turno donde entraron, el historial de comprobantes (incluidos los
-- anulados al reemitir) y las comandas con el estado de su impresión.
CREATE OR REPLACE FUNCTION ven_obtener_venta(p_id BIGINT)
RETURNS JSON LANGUAGE plpgsql STABLE AS $$
DECLARE pedido JSONB;
BEGIN
  pedido := (ven_obtener_pedido(p_id)::JSONB)->'registro';
  IF pedido IS NULL THEN RETURN json_build_object('registro', NULL); END IF;

  RETURN json_build_object('registro', pedido || jsonb_build_object(
    'fecha_cierre', (SELECT p.fecha_cierre FROM ven_pedido p WHERE p.id = p_id),
    'pagos', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'id', g.id, 'medio_pago', g.medio_pago,
        'nombre_medio', COALESCE((SELECT o.nombre FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
          WHERE l.codigo = 'MEDIO_PAGO' AND o.valor_entero = g.medio_pago LIMIT 1), g.medio_pago::TEXT),
        'monto', g.monto, 'estado', g.estado, 'id_comprobante', g.id_comprobante,
        'id_turno', g.id_turno, 'estado_turno', t.estado_turno, 'id_caja', t.id_caja, 'nombre_caja', cj.nombre,
        'fecha_creacion', g.fecha_creacion, 'fecha_modificacion', g.fecha_modificacion,
        'usuario', (SELECT trim(concat_ws(' ', u.nombres, u.apellidos)) FROM auth_usuario_datos u
          WHERE u.id = g.id_usuario_creacion)) ORDER BY g.id)
      FROM ven_pago g
      LEFT JOIN caj_turno t ON t.id = g.id_turno
      LEFT JOIN caj_caja cj ON cj.id = t.id_caja
      WHERE g.id_pedido = p_id), '[]'::JSONB),
    'comprobantes', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'id', c.id, 'tipo_comprobante', c.tipo_comprobante, 'serie', c.serie, 'correlativo', c.correlativo,
        'numero', c.serie || '-' || c.correlativo, 'receptor_tipo_doc', c.receptor_tipo_doc,
        'receptor_num_doc', c.receptor_num_doc, 'receptor_razon_social', c.receptor_razon_social,
        'monto_gravado', c.monto_gravado, 'monto_igv', c.monto_igv, 'monto_total', c.monto_total,
        'fecha_emision', c.fecha_emision, 'estado', c.estado, 'id_comprobante_origen', c.id_comprobante_origen,
        'items', COALESCE((SELECT jsonb_agg(jsonb_build_object('descripcion', d.descripcion, 'cantidad', d.cantidad,
            'unidad', d.unidad, 'precio_unitario', d.precio_unitario, 'monto_total', d.monto_total) ORDER BY d.id)
          FROM ven_comprobante_detalle d WHERE d.id_comprobante = c.id AND d.estado = 1), '[]'::JSONB))
        ORDER BY c.id DESC)
      FROM ven_comprobante c WHERE c.id_pedido = p_id), '[]'::JSONB),
    'comandas_impresion', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'id', c.id, 'numero', c.numero, 'id_estacion', c.id_estacion, 'estacion', e.nombre,
        'fecha_envio', c.fecha_envio, 'tipo', COALESCE(j.contenido->>'tipo', 'COMANDA'),
        'estado_impresion', j.estado, 'error_impresion', j.error,
        'cantidad_items', (SELECT count(*) FROM ven_pedido_detalle d WHERE d.id_comanda = c.id AND d.estado = 1))
        ORDER BY c.id)
      FROM ven_comanda c
      LEFT JOIN gen_estacion e ON e.id = c.id_estacion
      LEFT JOIN ven_impresion_trabajo j ON j.id_comanda = c.id
      WHERE c.id_pedido = p_id AND c.estado = 1), '[]'::JSONB)
  ));
END;
$$;
