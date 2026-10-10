ALTER TABLE gen_estacion ADD COLUMN IF NOT EXISTS es_caja_principal BOOLEAN NOT NULL DEFAULT FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_estacion_caja_principal ON gen_estacion(id_sucursal) WHERE es_caja_principal AND estado=1;

CREATE OR REPLACE FUNCTION gen_marcar_caja_principal(p_id BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE suc BIGINT;
BEGIN
  SELECT id_sucursal INTO suc FROM gen_estacion WHERE id=p_id AND estado=1;
  IF suc IS NULL THEN RAISE EXCEPTION 'Estación inactiva o inexistente'; END IF;
  PERFORM 1 FROM gen_sucursal WHERE id=suc FOR UPDATE;
  IF NOT EXISTS(SELECT 1 FROM gen_estacion WHERE id=p_id AND NULLIF(trim(impresora_ip),'') IS NOT NULL) THEN
    RAISE EXCEPTION 'Configure la impresora de la estación de caja'; END IF;
  UPDATE gen_estacion SET es_caja_principal=FALSE WHERE id_sucursal=suc AND es_caja_principal;
  UPDATE gen_estacion SET es_caja_principal=TRUE WHERE id=p_id;
  RETURN gen_obtener_estacion(p_id);
END $$;
