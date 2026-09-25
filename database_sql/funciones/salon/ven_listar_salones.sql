CREATE OR REPLACE FUNCTION ven_listar_salones(p_f JSONB) RETURNS JSON LANGUAGE sql AS $$
  WITH filtrados AS (
    SELECT s.* FROM ven_salon s
    WHERE (NULLIF(p_f->>'id_sucursal', '') IS NULL OR s.id_sucursal = (p_f->>'id_sucursal')::BIGINT)
      AND (COALESCE(p_f->>'estado', 'activos') = 'todos' OR s.estado = CASE WHEN p_f->>'estado' = 'inactivos' THEN 0 ELSE 1 END)
      AND (s.nombre ILIKE '%' || COALESCE(p_f->>'buscar', '') || '%' OR s.codigo ILIKE '%' || COALESCE(p_f->>'buscar', '') || '%')
  ), pagina AS (
    SELECT * FROM filtrados ORDER BY codigo, id
    LIMIT COALESCE((p_f->>'limite')::INTEGER, 10) OFFSET COALESCE((p_f->>'offset')::INTEGER, 0)
  )
  SELECT json_build_object('registros', COALESCE((SELECT json_agg(p) FROM pagina p), '[]'::JSON),
    'total', (SELECT count(*) FROM filtrados));
$$;
