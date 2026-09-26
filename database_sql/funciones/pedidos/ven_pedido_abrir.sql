CREATE OR REPLACE FUNCTION public.ven_pedido_abrir(p_id BIGINT, p_item BIGINT, p_datos JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE
  v_id BIGINT; v_tipo INTEGER := (p_datos->>'tipo_pedido')::INTEGER;
  v_mesa BIGINT := (p_datos->>'id_mesa')::BIGINT;
  v_sucursal BIGINT := (p_datos->>'id_sucursal')::BIGINT;
  v_mozo BIGINT := (p_datos->>'id_mozo')::BIGINT;
  v_turno BIGINT := (p_datos->>'id_turno')::BIGINT;
  v ven_mesa%ROWTYPE; v_salon ven_salon%ROWTYPE;
BEGIN
  IF v_tipo IS NULL OR v_tipo NOT IN (1,2,3) THEN RAISE EXCEPTION 'Tipo de pedido inválido'; END IF;
  IF v_tipo = 1 THEN
    IF v_mesa IS NULL THEN RAISE EXCEPTION 'El pedido en mesa requiere id_mesa'; END IF;
    PERFORM pg_advisory_xact_lock(505, (v_mesa % 2147483647)::INTEGER);
    SELECT * INTO v_salon FROM ven_salon WHERE id = (SELECT id_salon FROM ven_mesa WHERE id = v_mesa) FOR SHARE;
    SELECT * INTO v FROM ven_mesa WHERE id = v_mesa FOR UPDATE;
    IF NOT FOUND OR v.estado <> 1 OR v.estado_mesa <> 1 OR v_salon.estado <> 1 THEN RAISE EXCEPTION 'La mesa debe estar activa y LIBRE'; END IF;
    IF v_sucursal IS NOT NULL AND v_sucursal <> v_salon.id_sucursal THEN RAISE EXCEPTION 'La mesa pertenece a otra sucursal'; END IF;
    v_sucursal := v_salon.id_sucursal;
    IF EXISTS(SELECT 1 FROM ven_pedido WHERE id_mesa = v_mesa AND estado = 1 AND estado_pedido IN (1,2,3)) THEN RAISE EXCEPTION 'La mesa ya tiene un pedido en curso'; END IF;
  ELSIF v_mesa IS NOT NULL THEN RAISE EXCEPTION 'Solo los pedidos de tipo MESA admiten id_mesa';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM gen_sucursal WHERE id = v_sucursal AND estado = 1) THEN RAISE EXCEPTION 'Seleccione una sucursal activa'; END IF;
  IF NOT EXISTS(SELECT 1 FROM auth_usuario WHERE id = v_mozo AND estado = 1) THEN RAISE EXCEPTION 'Seleccione un mozo activo'; END IF;
  IF COALESCE((p_datos->>'num_comensales')::INTEGER,1) <= 0 THEN RAISE EXCEPTION 'Número de comensales inválido'; END IF;
  PERFORM ven_validar_turno_pedido(v_turno, v_sucursal);
  v_id := nextval(pg_get_serial_sequence('public.ven_pedido', 'id'));
  INSERT INTO ven_pedido(id,id_sucursal,id_mesa,id_mozo,id_turno,tipo_pedido,codigo,num_comensales,observacion,tasa_igv,id_usuario_creacion,id_usuario_modificacion)
  OVERRIDING SYSTEM VALUE VALUES(v_id,v_sucursal,v_mesa,v_mozo,v_turno,v_tipo,'PED-' || v_id,
    COALESCE((p_datos->>'num_comensales')::INTEGER,1),p_datos->>'observacion',COALESCE((p_datos->>'tasa_igv')::NUMERIC,18),p_usuario,p_usuario);
  UPDATE ven_mesa SET estado_mesa = 2, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = v_mesa;
  RETURN ven_obtener_pedido(v_id);
END;
$$;
