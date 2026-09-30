CREATE OR REPLACE FUNCTION public.alm_obtener_movimiento(p_id BIGINT)
RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registro', (
    SELECT to_jsonb(m) || jsonb_build_object('detalles', COALESCE((
      SELECT jsonb_agg(d ORDER BY d.numero_linea)
      FROM alm_movimiento_detalle d WHERE d.id_movimiento=m.id
    ),'[]'::JSONB))
    FROM alm_movimiento m WHERE m.id=p_id
  ));
$$;
