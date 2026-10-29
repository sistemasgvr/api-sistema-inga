DROP FUNCTION IF EXISTS public.not_listar(
    p_id_usuario BIGINT,
    p_canales TEXT[],
    p_solo_no_leidas BOOLEAN,
    p_canal VARCHAR,
    p_limite INTEGER,
    p_offset INTEGER,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION public.not_listar(
  p_id_usuario BIGINT,
  p_canales TEXT[],
  p_solo_no_leidas BOOLEAN DEFAULT FALSE,
  p_canal VARCHAR DEFAULT NULL,
  p_limite INTEGER DEFAULT 30,
  p_offset INTEGER DEFAULT 0,
  p_id_empresa BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE sql STABLE AS $$
  WITH visibles AS (
    SELECT n.id, n.canal, n.titulo, n.mensaje, n.severidad, n.ruta, n.id_referencia, n.creada_en,
           EXISTS (SELECT 1 FROM notificacion_lectura l
                   WHERE l.id_notificacion = n.id AND l.id_usuario = p_id_usuario) AS leida
    FROM notificaciones n
    WHERE ((n.ids_usuario_destino IS NULL AND n.canal = ANY(p_canales))
           OR p_id_usuario = ANY(n.ids_usuario_destino))
      AND (p_canal IS NULL OR n.canal = p_canal)
      AND (p_id_empresa IS NULL OR n.id_empresa IS NULL OR n.id_empresa = p_id_empresa)
  ), filtradas AS (
    SELECT * FROM visibles WHERE NOT (COALESCE(p_solo_no_leidas, FALSE) AND leida)
  )
  SELECT json_build_object(
    'registros', COALESCE((SELECT json_agg(r ORDER BY r.creada_en DESC) FROM (
      SELECT * FROM filtradas
      ORDER BY creada_en DESC
      LIMIT LEAST(GREATEST(COALESCE(p_limite, 30), 1), 100) OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) r), '[]'::JSON),
    'total', (SELECT count(*) FROM filtradas)
  );
$$;