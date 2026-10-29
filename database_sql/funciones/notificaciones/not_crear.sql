-- Crea una notificación. Las que crea el backend se envían en el acto (p_emitida);
-- las generadas desde SQL quedan pendientes para el despachador.
-- Con clave única repetida no crea nada y devuelve id NULL.
DROP FUNCTION IF EXISTS public.not_crear(
    p_canal VARCHAR,
    p_titulo VARCHAR,
    p_mensaje TEXT,
    p_severidad VARCHAR,
    p_ruta VARCHAR,
    p_id_referencia BIGINT
);
DROP FUNCTION IF EXISTS public.not_crear(
    p_canal VARCHAR,
    p_titulo VARCHAR,
    p_mensaje TEXT,
    p_severidad VARCHAR,
    p_ruta VARCHAR,
    p_id_referencia BIGINT,
    p_ids_usuario_destino BIGINT[],
    p_clave_unica VARCHAR,
    p_datos JSONB,
    p_emitida BOOLEAN
);
CREATE OR REPLACE FUNCTION public.not_crear(
  p_canal VARCHAR,
  p_titulo VARCHAR,
  p_mensaje TEXT,
  p_severidad VARCHAR,
  p_ruta VARCHAR,
  p_id_referencia BIGINT,
  p_ids_usuario_destino BIGINT[] DEFAULT NULL,
  p_clave_unica VARCHAR DEFAULT NULL,
  p_datos JSONB DEFAULT NULL,
  p_emitida BOOLEAN DEFAULT TRUE,
  p_id_empresa BIGINT DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_id UUID; v_creada TIMESTAMPTZ;
BEGIN
  INSERT INTO notificaciones (id_empresa, canal, titulo, mensaje, severidad, ruta, id_referencia,
                              ids_usuario_destino, clave_unica, datos, emitida_en)
  VALUES (p_id_empresa, p_canal, left(p_titulo, 120), p_mensaje, COALESCE(p_severidad, 'info'), left(p_ruta, 255),
          p_id_referencia, NULLIF(p_ids_usuario_destino, '{}'), p_clave_unica, p_datos,
          CASE WHEN p_emitida THEN now() END)
  ON CONFLICT (clave_unica) WHERE clave_unica IS NOT NULL DO NOTHING
  RETURNING id, creada_en INTO v_id, v_creada;
  RETURN json_build_object('id', v_id, 'creada_en', v_creada);
END; $$;
