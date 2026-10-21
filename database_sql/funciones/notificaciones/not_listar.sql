DROP FUNCTION IF EXISTS public.not_listar(
    p_id_usuario BIGINT,
    p_canales TEXT[]
);
CREATE OR REPLACE FUNCTION public.not_listar(
  p_id_usuario BIGINT,
  p_canales TEXT[]
) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object(
    'registros', COALESCE((SELECT json_agg(r) FROM (
      SELECT n.id, n.canal, n.titulo, n.mensaje, n.severidad, n.ruta, n.id_referencia, n.creada_en,
             EXISTS (SELECT 1 FROM notificacion_lectura l
                     WHERE l.id_notificacion = n.id AND l.id_usuario = p_id_usuario) AS leida
      FROM notificaciones n
      WHERE n.canal = ANY(p_canales)
      ORDER BY n.creada_en DESC
      LIMIT 100
    ) r), '[]'::JSON),
    'total', (SELECT count(*) FROM notificaciones n WHERE n.canal = ANY(p_canales))
  );
$$;
