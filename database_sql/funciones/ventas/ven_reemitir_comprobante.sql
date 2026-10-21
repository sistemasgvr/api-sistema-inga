-- Reemite el comprobante de una venta: anula el vigente y emite uno nuevo enlazado al anterior,
-- copiando ítems y montos. Los pagos pasan al nuevo comprobante.
DROP FUNCTION IF EXISTS ven_reemitir_comprobante(p_id_pedido BIGINT, p_datos JSONB, p_usuario BIGINT);
CREATE OR REPLACE FUNCTION ven_reemitir_comprobante(p_id_pedido BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE pedido ven_pedido%ROWTYPE; anterior ven_comprobante%ROWTYPE; persona cli_persona%ROWTYPE;
  correlativo gen_correlativo%ROWTYPE; nuevo BIGINT;
  tipo SMALLINT := (p_datos->>'tipo_comprobante')::SMALLINT;
  documento TEXT := COALESCE(btrim(p_datos->>'documento'), '');
BEGIN
  SELECT * INTO pedido FROM ven_pedido WHERE id = p_id_pedido AND estado = 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'La venta no existe' USING ERRCODE = 'P0002'; END IF;
  IF pedido.estado_pedido <> 4 THEN RAISE EXCEPTION 'Solo se reemite el comprobante de ventas cobradas'; END IF;

  SELECT * INTO anterior FROM ven_comprobante WHERE id_pedido = p_id_pedido AND estado = 1
    ORDER BY id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'La venta no tiene comprobante vigente (las ventas a crédito no emiten comprobante)'; END IF;

  IF tipo IS NULL OR tipo NOT IN (1,2,3) THEN RAISE EXCEPTION 'Seleccione un tipo de comprobante'; END IF;
  IF tipo = 2 AND documento !~ '^[0-9]{11}$' THEN RAISE EXCEPTION 'La factura requiere RUC de once dígitos'; END IF;
  IF tipo = 1 AND documento !~ '^([0-9]{8})?$' THEN RAISE EXCEPTION 'El DNI debe tener ocho dígitos'; END IF;
  IF tipo = 3 THEN documento := ''; END IF;

  IF tipo = 2 THEN
    SELECT * INTO persona FROM cli_persona WHERE num_documento = documento AND estado = 1 AND es_cliente;
    IF NOT FOUND OR NULLIF(btrim(persona.razon_social), '') IS NULL THEN
      RAISE EXCEPTION 'Registre al cliente con su RUC y razón social para facturar';
    END IF;
  ELSIF documento = '' THEN
    SELECT * INTO persona FROM cli_persona WHERE tipo_documento = 1 AND num_documento = '00000000' AND estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'Registre el cliente "Clientes varios" (DNI 00000000) para emitir sin documento'; END IF;
  ELSE
    SELECT * INTO persona FROM cli_persona WHERE tipo_documento = 1 AND num_documento = documento AND estado = 1 AND es_cliente;
  END IF;

  SELECT * INTO correlativo FROM gen_correlativo WHERE id_sucursal = pedido.id_sucursal AND tipo_documento = tipo AND estado = 1
    ORDER BY id LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Configure la serie del comprobante en esta sucursal'; END IF;
  UPDATE gen_correlativo SET ultimo_numero = ultimo_numero + 1 WHERE id = correlativo.id RETURNING * INTO correlativo;

  UPDATE ven_comprobante SET estado = 0, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = anterior.id;

  INSERT INTO ven_comprobante(id_pedido, id_persona, id_comprobante_origen, tipo_comprobante, receptor_tipo_doc,
    receptor_num_doc, receptor_razon_social, serie, correlativo, monto_gravado, monto_exonerado, monto_igv, monto_total,
    id_usuario_creacion, id_usuario_modificacion)
  VALUES(p_id_pedido, persona.id, anterior.id, tipo,
    COALESCE(persona.tipo_documento, CASE WHEN tipo = 2 THEN 6 ELSE 1 END),
    COALESCE(NULLIF(documento, ''), persona.num_documento),
    COALESCE(NULLIF(btrim(persona.razon_social), ''),
      NULLIF(btrim(concat_ws(' ', persona.nombres, persona.apellido_paterno, persona.apellido_materno)), '')),
    correlativo.serie, lpad(correlativo.ultimo_numero::TEXT, correlativo.longitud, '0'),
    anterior.monto_gravado, anterior.monto_exonerado, anterior.monto_igv, anterior.monto_total, p_usuario, p_usuario)
  RETURNING id INTO nuevo;

  INSERT INTO ven_comprobante_detalle(id_comprobante, id_pedido_detalle, descripcion, cantidad, unidad, precio_unitario, monto_total)
  SELECT nuevo, d.id_pedido_detalle, d.descripcion, d.cantidad, d.unidad, d.precio_unitario, d.monto_total
  FROM ven_comprobante_detalle d WHERE d.id_comprobante = anterior.id AND d.estado = 1 ORDER BY d.id;

  UPDATE ven_pago SET id_comprobante = nuevo, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id_comprobante = anterior.id AND estado = 1;

  RETURN ven_obtener_venta(p_id_pedido);
END;
$$;
