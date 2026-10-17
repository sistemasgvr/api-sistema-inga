CREATE OR REPLACE FUNCTION public.not_marcar_leida(
  p_id_notificacion UUID,
  p_id_usuario BIGINT
) RETURNS JSON LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO notificacion_lectura (id_notificacion, id_usuario)
  VALUES (p_id_notificacion, p_id_usuario)
  ON CONFLICT (id_notificacion, id_usuario) DO NOTHING;
  RETURN json_build_object('ok', TRUE);
END; $$;
