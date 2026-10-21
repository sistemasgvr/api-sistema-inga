-- Cambia el medio de pago de una venta cobrada: anula el pago y registra uno nuevo en el mismo turno.
-- Si el turno ya se cerró recalcula su cierre. El crédito (4) se corrige desde CxC.
DROP FUNCTION IF EXISTS ven_cambiar_medio_pago(p_id_pago BIGINT, p_medio SMALLINT, p_usuario BIGINT);
CREATE OR REPLACE FUNCTION ven_cambiar_medio_pago(p_id_pago BIGINT, p_medio SMALLINT, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE g ven_pago%ROWTYPE; pedido ven_pedido%ROWTYPE; turno caj_turno%ROWTYPE; nombre_anterior TEXT; nombre_nuevo TEXT;
BEGIN
  SELECT * INTO g FROM ven_pago WHERE id = p_id_pago FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El pago no existe' USING ERRCODE = 'P0002'; END IF;
  IF g.estado <> 1 THEN RAISE EXCEPTION 'El pago ya fue anulado o reemplazado'; END IF;

  SELECT * INTO pedido FROM ven_pedido WHERE id = g.id_pedido FOR UPDATE;
  IF pedido.estado_pedido <> 4 THEN RAISE EXCEPTION 'Solo se cambia el medio de pago de ventas cobradas'; END IF;

  IF g.medio_pago NOT IN (1,2,3) THEN
    RAISE EXCEPTION 'Los pagos a crédito no se cambian aquí: corrígelos desde Cuentas por cobrar';
  END IF;
  IF p_medio IS NULL OR p_medio NOT IN (1,2,3) THEN RAISE EXCEPTION 'Elige efectivo, Yape o tarjeta'; END IF;
  IF p_medio = g.medio_pago THEN RAISE EXCEPTION 'El pago ya está registrado con ese medio'; END IF;

  SELECT o.nombre INTO nombre_nuevo FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = 'MEDIO_PAGO' AND l.estado = 1 AND o.estado = 1 AND o.valor_entero = p_medio;
  IF NOT FOUND THEN RAISE EXCEPTION 'El medio de pago no está activo'; END IF;
  SELECT o.nombre INTO nombre_anterior FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = 'MEDIO_PAGO' AND o.valor_entero = g.medio_pago;

  SELECT * INTO turno FROM caj_turno WHERE id = g.id_turno FOR UPDATE;
  IF NOT FOUND OR turno.estado <> 1 THEN RAISE EXCEPTION 'El turno de caja de este pago no existe o fue anulado'; END IF;

  UPDATE ven_pago SET estado = 0, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = g.id;
  INSERT INTO ven_pago(id_pedido, id_turno, id_comprobante, id_persona, id_convenio, medio_pago, monto,
    monto_recibido, id_usuario_creacion, id_usuario_modificacion)
  VALUES(g.id_pedido, g.id_turno, g.id_comprobante, g.id_persona, g.id_convenio, p_medio, g.monto,
    CASE WHEN p_medio = 1 THEN g.monto END, p_usuario, p_usuario);

  IF turno.estado_turno = 2 THEN
    PERFORM caj_recalcular_cierre_turno(turno.id,
      format('Corrección %s: S/ %s de %s a %s', pedido.codigo, g.monto,
        COALESCE(nombre_anterior, g.medio_pago::TEXT), nombre_nuevo),
      p_usuario);
  END IF;

  RETURN ven_obtener_venta(g.id_pedido);
END;
$$;
