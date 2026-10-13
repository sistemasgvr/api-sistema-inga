-- Receta vigente (última versión activa) de un producto; NULL si no tiene.
CREATE OR REPLACE FUNCTION pro_receta_vigente(p_producto BIGINT) RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT id FROM pro_receta WHERE id_producto=p_producto AND estado=1 AND vigente AND rendimiento_porciones>0
  ORDER BY version DESC LIMIT 1;
$$;
