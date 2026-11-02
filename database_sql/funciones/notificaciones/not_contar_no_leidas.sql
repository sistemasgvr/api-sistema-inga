DROP FUNCTION IF EXISTS public.not_contar_no_leidas(
    p_id_usuario BIGINT,
    p_canales TEXT[]
);
DROP FUNCTION IF EXISTS public.not_contar_no_leidas(
    p_id_usuario BIGINT,
    p_canales TEXT[],
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
DROP FUNCTION IF EXISTS public.not_contar_no_leidas(
    p_id_usuario BIGINT,
    p_canales TEXT[],
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION public.not_contar_no_leidas(
  p_id_usuario BIGINT,
  p_canales TEXT[],
  p_id_empresa BIGINT DEFAULT NULL,
  p_id_sucursal BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE sql STABLE AS $$
  SELECT json_build_object('total', (
    SELECT count(*) FROM notificaciones n
    WHERE ((n.ids_usuario_destino IS NULL AND n.canal = ANY(p_canales))
           OR p_id_usuario = ANY(n.ids_usuario_destino))
      AND (p_id_empresa IS NULL OR n.id_empresa IS NULL OR n.id_empresa = p_id_empresa)
      AND (p_id_sucursal IS NULL OR n.id_sucursal IS NULL OR n.id_sucursal = p_id_sucursal)
      AND NOT EXISTS (
        SELECT 1 FROM notificacion_lectura l
        WHERE l.id_notificacion = n.id AND l.id_usuario = p_id_usuario
      )
  ));
$$;
