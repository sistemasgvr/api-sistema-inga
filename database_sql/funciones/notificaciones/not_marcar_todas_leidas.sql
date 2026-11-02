-- Marca como leídas todas las notificaciones visibles para el usuario (opcionalmente de un canal).
DROP FUNCTION IF EXISTS public.not_marcar_todas_leidas(
    p_id_usuario BIGINT,
    p_canales TEXT[],
    p_canal VARCHAR
);
DROP FUNCTION IF EXISTS public.not_marcar_todas_leidas(
    p_id_usuario BIGINT,
    p_canales TEXT[],
    p_canal VARCHAR,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
DROP FUNCTION IF EXISTS public.not_marcar_todas_leidas(
    p_id_usuario BIGINT,
    p_canales TEXT[],
    p_canal VARCHAR,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION public.not_marcar_todas_leidas(
  p_id_usuario BIGINT,
  p_canales TEXT[],
  p_canal VARCHAR DEFAULT NULL,
  p_id_empresa BIGINT DEFAULT NULL,
  p_id_sucursal BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_total INTEGER;
BEGIN
  INSERT INTO notificacion_lectura (id_notificacion, id_usuario)
  SELECT n.id, p_id_usuario
  FROM notificaciones n
  WHERE ((n.ids_usuario_destino IS NULL AND n.canal = ANY(p_canales))
         OR p_id_usuario = ANY(n.ids_usuario_destino))
    AND (p_canal IS NULL OR n.canal = p_canal)
    AND (p_id_empresa IS NULL OR n.id_empresa IS NULL OR n.id_empresa = p_id_empresa)
    AND (p_id_sucursal IS NULL OR n.id_sucursal IS NULL OR n.id_sucursal = p_id_sucursal)
  ON CONFLICT (id_notificacion, id_usuario) DO NOTHING;
  GET DIAGNOSTICS v_total = ROW_COUNT;
  RETURN json_build_object('ok', TRUE, 'total', v_total);
END; $$;
