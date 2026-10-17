CREATE OR REPLACE FUNCTION public.not_contar_no_leidas(
  p_id_usuario BIGINT,
  p_canales TEXT[]
) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('total', (
    SELECT count(*) FROM notificaciones n
    WHERE n.canal = ANY(p_canales)
      AND NOT EXISTS (
        SELECT 1 FROM notificacion_lectura l
        WHERE l.id_notificacion = n.id AND l.id_usuario = p_id_usuario
      )
  ));
$$;
