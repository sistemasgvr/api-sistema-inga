-- Marca como leídas todas las notificaciones visibles para el usuario (opcionalmente de un canal).
DROP FUNCTION IF EXISTS public.not_marcar_todas_leidas(
    p_id_usuario BIGINT,
    p_canales TEXT[],
    p_canal VARCHAR
);
CREATE OR REPLACE FUNCTION public.not_marcar_todas_leidas(
  p_id_usuario BIGINT,
  p_canales TEXT[],
  p_canal VARCHAR DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_total INTEGER;
BEGIN
  INSERT INTO notificacion_lectura (id_notificacion, id_usuario)
  SELECT n.id, p_id_usuario
  FROM notificaciones n
  WHERE ((n.ids_usuario_destino IS NULL AND n.canal = ANY(p_canales))
         OR p_id_usuario = ANY(n.ids_usuario_destino))
    AND (p_canal IS NULL OR n.canal = p_canal)
  ON CONFLICT (id_notificacion, id_usuario) DO NOTHING;
  GET DIAGNOSTICS v_total = ROW_COUNT;
  RETURN json_build_object('ok', TRUE, 'total', v_total);
END; $$;
