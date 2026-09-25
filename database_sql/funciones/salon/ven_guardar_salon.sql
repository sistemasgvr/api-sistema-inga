CREATE OR REPLACE FUNCTION ven_guardar_salon(p_id BIGINT, p_d JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_salon%ROWTYPE; v_anterior ven_salon%ROWTYPE;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_anterior FROM ven_salon WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN RETURN json_build_object('registro', NULL); END IF;
  END IF;
  v := jsonb_populate_record(v_anterior, p_d);
  v.codigo := upper(trim(v.codigo)); v.nombre := trim(v.nombre);
  v.posicion_x := COALESCE(v.posicion_x, 0); v.posicion_y := COALESCE(v.posicion_y, 0);
  v.ancho := COALESCE(v.ancho, 200); v.alto := COALESCE(v.alto, 150);
  IF COALESCE(v.codigo, '') = '' OR COALESCE(v.nombre, '') = '' THEN
    RETURN json_build_object('error', 'Código y nombre son obligatorios');
  END IF;
  IF v.posicion_x < 0 OR v.posicion_x > 10000 OR v.posicion_y < 0 OR v.posicion_y > 10000
    OR v.ancho < 200 OR v.ancho > 5000 OR v.alto < 150 OR v.alto > 5000 THEN
    RETURN json_build_object('error', 'Posición o dimensiones fuera de rango');
  END IF;
  PERFORM 1 FROM gen_sucursal WHERE id = v.id_sucursal AND estado = 1 FOR SHARE;
  IF NOT FOUND THEN RETURN json_build_object('error', 'La sucursal no existe o está inactiva'); END IF;
  IF p_id IS NOT NULL AND v.id_sucursal <> v_anterior.id_sucursal
    AND EXISTS (SELECT 1 FROM ven_mesa WHERE id_salon = p_id) THEN
    RETURN json_build_object('error', 'No se puede cambiar de sucursal un salón con mesas registradas');
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO ven_salon (id_sucursal, codigo, nombre, posicion_x, posicion_y, ancho, alto, id_usuario_creacion, id_usuario_modificacion)
    VALUES (v.id_sucursal, v.codigo, v.nombre, v.posicion_x, v.posicion_y, v.ancho, v.alto, p_usuario, p_usuario) RETURNING id INTO p_id;
  ELSE
    UPDATE ven_salon SET id_sucursal = v.id_sucursal, codigo = v.codigo, nombre = v.nombre,
      posicion_x = v.posicion_x, posicion_y = v.posicion_y, ancho = v.ancho, alto = v.alto,
      id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = p_id;
  END IF;
  RETURN ven_obtener_salon(p_id);
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('error', 'Ya existe un salón con ese código en la sucursal (incluso inactivo)');
END;
$$;
