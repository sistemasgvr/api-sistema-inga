-- Con p_id_sucursal (la de la sesión) solo devuelve esa sucursal.
DROP FUNCTION IF EXISTS ven_sucursales_ambientes();
DROP FUNCTION IF EXISTS ven_sucursales_ambientes(p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION ven_sucursales_ambientes(p_id_sucursal BIGINT DEFAULT NULL)
RETURNS JSON LANGUAGE sql AS $$
  SELECT COALESCE(json_agg(s), '[]'::JSON) FROM (
    SELECT id, codigo, nombre FROM gen_sucursal
    WHERE estado = 1 AND (p_id_sucursal IS NULL OR id = p_id_sucursal)
    ORDER BY nombre, id
  ) s;
$$;
