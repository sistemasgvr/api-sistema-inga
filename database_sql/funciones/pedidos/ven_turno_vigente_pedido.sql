-- Un pedido puede seguir atendiéndose después de cerrar su turno de apertura:
-- basta un turno abierto de la misma sucursal. id_turno del pedido se conserva
-- como referencia histórica; se prefiere ese turno y luego el del usuario.
DROP FUNCTION IF EXISTS public.ven_turno_vigente_pedido(p_sucursal BIGINT, p_turno_preferido BIGINT, p_usuario BIGINT);
CREATE OR REPLACE FUNCTION public.ven_turno_vigente_pedido(p_sucursal BIGINT, p_turno_preferido BIGINT, p_usuario BIGINT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_turno BIGINT;
BEGIN
  SELECT t.id INTO v_turno
  FROM caj_turno t JOIN caj_caja c ON c.id=t.id_caja
  WHERE t.estado=1 AND t.estado_turno=1 AND c.estado=1 AND c.id_sucursal=p_sucursal
  ORDER BY (t.id=p_turno_preferido) DESC, (t.id_cajero=p_usuario) DESC, t.id DESC
  LIMIT 1 FOR SHARE OF t,c;
  IF v_turno IS NULL THEN RAISE EXCEPTION 'Se requiere un turno abierto de la misma sucursal'; END IF;
  RETURN v_turno;
END;
$$;
