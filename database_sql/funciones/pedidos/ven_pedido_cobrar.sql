-- Cobro completo: no deja pagos, comprobantes ni créditos parciales si falla.
CREATE OR REPLACE FUNCTION ven_pedido_cobrar(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; t BIGINT; persona cli_persona%ROWTYPE; convenio cli_convenio%ROWTYPE;
  medio SMALLINT:=(p_datos->>'medio_pago')::SMALLINT; tipo SMALLINT:=(p_datos->>'tipo_comprobante')::SMALLINT;
  pago BIGINT; comprobante BIGINT; correlativo gen_correlativo%ROWTYPE; resultado JSON;
  credito BOOLEAN:=COALESCE((p_datos->>'credito')::BOOLEAN,FALSE); monto_credito NUMERIC; excedente NUMERIC:=0; disponible NUMERIC;
BEGIN
  v:=ven_bloquear_pedido(p_id);
  IF v.estado_pedido=4 THEN RETURN ven_obtener_pedido(p_id); END IF;
  IF v.estado_pedido NOT IN (1,2,3) THEN RAISE EXCEPTION 'El pedido no admite cobros'; END IF;
  IF EXISTS(SELECT 1 FROM ven_pedido_detalle WHERE id_pedido=p_id AND estado=1 AND tipo_linea<>3
    AND (id_comanda IS NULL OR cantidad_entregada+cantidad_cancelada<cantidad)) THEN RAISE EXCEPTION 'Hay platos pendientes de entregar'; END IF;
  IF EXISTS(SELECT 1 FROM ven_pago WHERE id_pedido=p_id AND estado=1) THEN RAISE EXCEPTION 'El pedido ya tiene pagos; revise el saldo antes de cobrar'; END IF;
  PERFORM ven_recalcular_pedido(p_id,p_usuario);
  SELECT * INTO v FROM ven_pedido WHERE id=p_id;
  IF v.monto_total<=0 THEN RAISE EXCEPTION 'El pedido no tiene importe por cobrar'; END IF;
  -- Se exige el turno del cajero; un administrador puede usar el único turno de la sucursal.
  SELECT ct.id INTO t FROM caj_turno ct JOIN caj_caja c ON c.id=ct.id_caja
    WHERE ct.estado=1 AND ct.estado_turno=1 AND c.estado=1 AND c.id_sucursal=v.id_sucursal AND ct.id_cajero=p_usuario
    ORDER BY ct.id DESC LIMIT 1 FOR SHARE OF ct,c;
  IF t IS NULL THEN RAISE EXCEPTION 'El usuario debe tener un turno abierto en esta sucursal para cobrar'; END IF;
  IF credito THEN
    IF COALESCE(p_datos->>'documento','') !~ '^[0-9]{8}$' THEN RAISE EXCEPTION 'Ingrese el DNI de ocho dígitos del cliente'; END IF;
    SELECT * INTO persona FROM cli_persona WHERE num_documento=p_datos->>'documento' AND tipo_documento=1 AND estado=1 AND es_cliente FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El DNI no corresponde a un cliente registrado'; END IF;
    SELECT * INTO convenio FROM cli_convenio WHERE id=persona.id_convenio AND estado=1 FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El cliente necesita un convenio activo'; END IF;
    -- limite_credito es el techo de la DEUDA, no del cobro: a crédito entra solo lo que
    -- le falta al cliente para llegar al tope y el resto se cobra en efectivo. El saldo
    -- se lee con la fila de la persona ya bloqueada arriba (FOR UPDATE), así dos cajeros
    -- que cobran al mismo cliente se serializan y el segundo ve la deuda del primero.
    -- Un límite de 0 (o NULL) NO es "crédito cero": es SIN TOPE, la cuenta de consorcio
    -- que se liquida a fin de período. Ahí entra el pedido completo a crédito y no hay
    -- efectivo que confirmar. Mismo criterio que nivelCredito() en el front y que
    -- cxc_listar_saldos.
    -- OJO: cxc_registrar_consumo, llamada desde la pantalla de CxC para un cargo manual,
    -- NO bloquea la persona; por esa vía la garantía de concurrencia no aplica.
    IF COALESCE(convenio.limite_credito,0)<=0 THEN
      monto_credito:=v.monto_total;
      excedente:=0;
    ELSE
      disponible:=GREATEST(convenio.limite_credito-cxc_calcular_saldo_persona(persona.id),0);
      monto_credito:=LEAST(v.monto_total,disponible);
      excedente:=v.monto_total-monto_credito;
    END IF;
    IF excedente>0 AND NOT COALESCE((p_datos->>'efectivo_confirmado')::BOOLEAN,FALSE) THEN
      RAISE EXCEPTION 'Confirme la recepción de S/ % en efectivo por el excedente',excedente;
    END IF;
    medio:=4;
  ELSE
    IF tipo IS NULL OR tipo NOT IN (1,2,3) THEN RAISE EXCEPTION 'Seleccione un tipo de comprobante'; END IF;
    IF medio IS NULL OR medio=4 OR NOT EXISTS(SELECT 1 FROM gen_lista_opcion o JOIN gen_lista l ON l.id=o.id_lista
      WHERE l.codigo='MEDIO_PAGO' AND l.estado=1 AND o.estado=1 AND o.valor_entero=medio) THEN RAISE EXCEPTION 'Seleccione un medio de pago válido'; END IF;
    IF tipo=2 AND COALESCE(p_datos->>'documento','') !~ '^[0-9]{11}$' THEN RAISE EXCEPTION 'La factura requiere RUC de once dígitos'; END IF;
    IF tipo=2 THEN
      SELECT * INTO persona FROM cli_persona WHERE num_documento=p_datos->>'documento' AND estado=1 AND es_cliente;
      IF NOT FOUND OR NULLIF(btrim(persona.razon_social),'') IS NULL THEN RAISE EXCEPTION 'Registre al cliente con su RUC y razón social para facturar'; END IF;
    END IF;
    SELECT * INTO correlativo FROM gen_correlativo WHERE id_sucursal=v.id_sucursal AND tipo_documento=tipo AND estado=1
      ORDER BY id LIMIT 1 FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Configure la serie del comprobante en esta sucursal antes de cobrar'; END IF;
    UPDATE gen_correlativo SET ultimo_numero=ultimo_numero+1 WHERE id=correlativo.id RETURNING * INTO correlativo;
    INSERT INTO ven_comprobante(id_pedido,id_persona,tipo_comprobante,receptor_num_doc,receptor_razon_social,serie,correlativo,
      monto_gravado,monto_igv,monto_total,id_usuario_creacion,id_usuario_modificacion)
    VALUES(p_id,persona.id,tipo,NULLIF(p_datos->>'documento',''),persona.razon_social,correlativo.serie,
      lpad(correlativo.ultimo_numero::TEXT,correlativo.longitud,'0'),v.monto_subtotal,v.monto_igv,v.monto_total,p_usuario,p_usuario) RETURNING id INTO comprobante;
    INSERT INTO ven_comprobante_detalle(id_comprobante,id_pedido_detalle,descripcion,cantidad,unidad,precio_unitario,monto_total)
    SELECT comprobante,d.id,p.nombre,d.cantidad-d.cantidad_cancelada,u.simbolo,d.precio_unitario,d.monto_subtotal
      FROM ven_pedido_detalle d JOIN pro_producto p ON p.id=d.id_producto JOIN pro_unidad_medida u ON u.id=p.id_unidad_medida
      WHERE d.id_pedido=p_id AND d.estado=1 AND d.tipo_linea<>3 AND d.cantidad>d.cantidad_cancelada;
  END IF;
  -- Sin crédito disponible no se registra pago de crédito: su INSERT chocaría con el
  -- CHECK (monto > 0) de ven_pago. El excedente en efectivo se cobra igual, más abajo.
  IF NOT credito OR monto_credito>0 THEN
    INSERT INTO ven_pago(id_pedido,id_turno,id_comprobante,id_persona,id_convenio,medio_pago,monto,id_usuario_creacion,id_usuario_modificacion)
      VALUES(p_id,t,comprobante,persona.id,convenio.id,medio,CASE WHEN credito THEN monto_credito ELSE v.monto_total END,p_usuario,p_usuario) RETURNING id INTO pago;
  END IF;
  IF credito THEN
    IF monto_credito>0 THEN
      resultado:=cxc_registrar_consumo(persona.id,monto_credito,CURRENT_DATE,p_id,pago,'Pedido '||v.codigo,p_usuario);
      IF resultado->>'error' IS NOT NULL THEN RAISE EXCEPTION '%',resultado->>'error'; END IF;
    END IF;
    UPDATE ven_pedido SET id_persona=persona.id WHERE id=p_id;
    IF excedente>0 THEN
      INSERT INTO ven_pago(id_pedido,id_turno,id_persona,medio_pago,monto,monto_recibido,id_usuario_creacion,id_usuario_modificacion)
        VALUES(p_id,t,persona.id,1,excedente,excedente,p_usuario,p_usuario);
    END IF;
  END IF;
  UPDATE ven_pedido SET estado_pedido=4,monto_pagado=v.monto_total,fecha_cierre=CURRENT_TIMESTAMP,
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=p_id;
  UPDATE ven_mesa SET estado_mesa=1,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=v.id_mesa;
  RETURN ven_obtener_pedido(p_id);
END $$;

CREATE OR REPLACE FUNCTION ven_pedido_credito(p_id BIGINT,p_item BIGINT,p_datos JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
BEGIN RETURN ven_pedido_cobrar(p_id,p_item,p_datos||'{"credito":true}'::JSONB,p_usuario); END $$;
