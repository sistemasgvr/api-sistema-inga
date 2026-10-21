DROP FUNCTION IF EXISTS public.not_crear(
    p_canal VARCHAR,
    p_titulo VARCHAR,
    p_mensaje TEXT,
    p_severidad VARCHAR,
    p_ruta VARCHAR,
    p_id_referencia BIGINT
);
CREATE OR REPLACE FUNCTION public.not_crear(
  p_canal VARCHAR,
  p_titulo VARCHAR,
  p_mensaje TEXT,
  p_severidad VARCHAR,
  p_ruta VARCHAR,
  p_id_referencia BIGINT
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO notificaciones (canal, titulo, mensaje, severidad, ruta, id_referencia)
  VALUES (p_canal, p_titulo, p_mensaje, p_severidad, p_ruta, p_id_referencia)
  RETURNING id INTO v_id;
  RETURN json_build_object('id', v_id);
END; $$;
