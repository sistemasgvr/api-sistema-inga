CREATE OR REPLACE FUNCTION ven_estado_mesa(p_id BIGINT, p_estado INTEGER, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_mesa%ROWTYPE;
BEGIN
  PERFORM pg_advisory_xact_lock(505, (p_id % 2147483647)::INTEGER);
  PERFORM 1 FROM ven_salon WHERE id = (SELECT id_salon FROM ven_mesa WHERE id = p_id) FOR UPDATE;
  SELECT * INTO v FROM ven_mesa WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN json_build_object('registro', NULL); END IF;
  IF p_estado NOT IN (0,1) THEN RETURN json_build_object('error', 'Estado inválido'); END IF;
  IF v.estado_mesa IN (2,3) OR EXISTS (
    SELECT 1 FROM ven_pedido WHERE id_mesa = p_id AND estado = 1 AND estado_pedido IN (1,2,3)
  ) THEN RETURN json_build_object('error', 'No se puede cambiar la baja de una mesa con atención en curso'); END IF;
  IF p_estado = 1 AND NOT EXISTS (
    SELECT 1 FROM ven_salon s JOIN gen_sucursal g ON g.id = s.id_sucursal WHERE s.id = v.id_salon AND s.estado = 1 AND g.estado = 1
  ) THEN RETURN json_build_object('error', 'Active primero el salón y la sucursal'); END IF;
  UPDATE ven_mesa SET estado = p_estado, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = p_id;
  RETURN ven_obtener_mesa(p_id);
END;
$$;
