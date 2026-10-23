-- Borra el historial más antiguo que p_dias (las lecturas caen en cascada).
DROP FUNCTION IF EXISTS public.not_depurar(p_dias INTEGER);
CREATE OR REPLACE FUNCTION public.not_depurar(
  p_dias INTEGER DEFAULT 60
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_total INTEGER;
BEGIN
  DELETE FROM notificaciones
  WHERE creada_en < now() - make_interval(days => GREATEST(COALESCE(p_dias, 60), 1));
  GET DIAGNOSTICS v_total = ROW_COUNT;
  RETURN json_build_object('eliminadas', v_total);
END; $$;
