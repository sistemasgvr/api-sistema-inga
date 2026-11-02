-- Con p_id_sucursal (la de la sesión) solo devuelve mesas de esa sucursal.
DROP FUNCTION IF EXISTS ven_obtener_mesa(p_id BIGINT);
DROP FUNCTION IF EXISTS ven_obtener_mesa(p_id BIGINT, p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION ven_obtener_mesa(p_id BIGINT, p_id_sucursal BIGINT DEFAULT NULL)
RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registro', (
    SELECT row_to_json(m)
    FROM ven_mesa m
    JOIN ven_salon s ON s.id = m.id_salon
    WHERE m.id = p_id
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
  ));
$$;
