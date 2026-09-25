CREATE OR REPLACE FUNCTION ven_estado_salon(p_id BIGINT, p_estado INTEGER, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_salon%ROWTYPE;
BEGIN
  SELECT * INTO v FROM ven_salon WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN json_build_object('registro', NULL); END IF;
  IF p_estado NOT IN (0,1) THEN RETURN json_build_object('error', 'Estado inválido'); END IF;
  IF p_estado = 0 AND EXISTS (SELECT 1 FROM ven_mesa WHERE id_salon = p_id AND estado = 1) THEN
    RETURN json_build_object('error', 'Desactive primero las mesas del salón');
  END IF;
  IF p_estado = 1 AND NOT EXISTS (SELECT 1 FROM gen_sucursal WHERE id = v.id_sucursal AND estado = 1) THEN
    RETURN json_build_object('error', 'La sucursal está inactiva');
  END IF;
  UPDATE ven_salon SET estado = p_estado, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = p_id;
  RETURN ven_obtener_salon(p_id);
END;
$$;
