CREATE OR REPLACE FUNCTION public.ven_factor_unidad(p_origen BIGINT, p_destino BIGINT)
RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
DECLARE v NUMERIC;
BEGIN
  IF p_origen = p_destino THEN RETURN 1; END IF;
  SELECT factor INTO v FROM pro_unidad_conversion WHERE id_unidad_origen = p_origen AND id_unidad_destino = p_destino AND estado = 1;
  IF v IS NULL THEN
    SELECT 1 / factor INTO v FROM pro_unidad_conversion WHERE id_unidad_origen = p_destino AND id_unidad_destino = p_origen AND estado = 1;
  END IF;
  IF v IS NULL OR v <= 0 THEN RAISE EXCEPTION 'No existe conversión de unidad % a %', p_origen, p_destino; END IF;
  RETURN v;
END;
$$;
