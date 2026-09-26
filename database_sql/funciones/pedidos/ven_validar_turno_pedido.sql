CREATE OR REPLACE FUNCTION public.ven_validar_turno_pedido(p_turno BIGINT, p_sucursal BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  PERFORM 1 FROM caj_turno t JOIN caj_caja c ON c.id = t.id_caja
  WHERE t.id = p_turno AND t.estado = 1 AND t.estado_turno = 1
    AND c.estado = 1 AND c.id_sucursal = p_sucursal FOR SHARE OF t, c;
  IF NOT FOUND THEN RAISE EXCEPTION 'Se requiere un turno abierto de la misma sucursal'; END IF;
END;
$$;
