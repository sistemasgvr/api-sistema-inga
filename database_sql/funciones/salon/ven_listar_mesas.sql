CREATE OR REPLACE FUNCTION ven_listar_mesas(p_f JSONB) RETURNS JSON LANGUAGE sql AS $$
  WITH filtrados AS (
    SELECT m.* FROM ven_mesa m JOIN ven_salon s ON s.id = m.id_salon
    WHERE (NULLIF(p_f->>'id_sucursal', '') IS NULL OR s.id_sucursal = (p_f->>'id_sucursal')::BIGINT)
      AND (NULLIF(p_f->>'id_salon', '') IS NULL OR m.id_salon = (p_f->>'id_salon')::BIGINT)
      AND (COALESCE(p_f->>'estado', 'activos') = 'todos' OR m.estado = CASE WHEN p_f->>'estado' = 'inactivos' THEN 0 ELSE 1 END)
      AND m.codigo ILIKE '%' || COALESCE(p_f->>'buscar', '') || '%'
  ), pagina AS (
    SELECT * FROM filtrados ORDER BY codigo, id
    LIMIT COALESCE((p_f->>'limite')::INTEGER, 10) OFFSET COALESCE((p_f->>'offset')::INTEGER, 0)
  )
  SELECT json_build_object('registros', COALESCE((SELECT json_agg(p) FROM pagina p), '[]'::JSON),
    'total', (SELECT count(*) FROM filtrados));
$$;
