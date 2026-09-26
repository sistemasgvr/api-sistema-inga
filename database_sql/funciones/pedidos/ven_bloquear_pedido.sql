CREATE OR REPLACE FUNCTION public.ven_bloquear_pedido(p_id BIGINT)
RETURNS ven_pedido LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; v_mesa BIGINT;
BEGIN
  SELECT id_mesa INTO v_mesa FROM ven_pedido WHERE id = p_id AND estado = 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido no encontrado' USING ERRCODE = 'P0002'; END IF;
  -- Mismo orden que mantenimiento de ambientes: advisory de mesa, salón, mesa, pedido.
  IF v_mesa IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(505, (v_mesa % 2147483647)::INTEGER);
    PERFORM 1 FROM ven_salon WHERE id = (SELECT id_salon FROM ven_mesa WHERE id = v_mesa) FOR SHARE;
    PERFORM 1 FROM ven_mesa WHERE id = v_mesa FOR UPDATE;
  END IF;
  SELECT * INTO v FROM ven_pedido WHERE id = p_id AND estado = 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido no encontrado' USING ERRCODE = 'P0002'; END IF;
  RETURN v;
END;
$$;
