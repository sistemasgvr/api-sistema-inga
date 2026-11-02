-- Con p_id_sucursal (la de la sesión) solo devuelve salones de esa sucursal.
DROP FUNCTION IF EXISTS ven_obtener_salon(p_id BIGINT);
DROP FUNCTION IF EXISTS ven_obtener_salon(p_id BIGINT, p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION ven_obtener_salon(p_id BIGINT, p_id_sucursal BIGINT DEFAULT NULL)
RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registro', (
    SELECT row_to_json(s)
    FROM ven_salon s
    WHERE s.id = p_id
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
  ));
$$;
