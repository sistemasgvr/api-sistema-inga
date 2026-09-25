CREATE OR REPLACE FUNCTION ven_obtener_salon(p_id BIGINT) RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registro', (SELECT row_to_json(s) FROM ven_salon s WHERE id = p_id));
$$;
