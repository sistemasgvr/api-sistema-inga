CREATE OR REPLACE FUNCTION ven_sucursales_ambientes() RETURNS JSON LANGUAGE sql AS $$
  SELECT COALESCE(json_agg(s), '[]'::JSON) FROM (
    SELECT id, codigo, nombre FROM gen_sucursal WHERE estado = 1 ORDER BY nombre, id
  ) s;
$$;
