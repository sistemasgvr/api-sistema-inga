CREATE OR REPLACE FUNCTION ven_obtener_mesa(p_id BIGINT) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registro', (SELECT row_to_json(m) FROM ven_mesa m WHERE id = p_id));
$$;
