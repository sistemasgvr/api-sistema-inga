CREATE OR REPLACE FUNCTION ven_guardar_mesa(p_id BIGINT, p_d JSONB, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_mesa%ROWTYPE; v_anterior ven_mesa%ROWTYPE;
BEGIN
  -- Serializa el mantenimiento de la misma mesa antes de leer su salón actual.
  -- Evita que un traslado concurrente invalide el bloqueo del salón de origen.
  IF p_id IS NOT NULL THEN PERFORM pg_advisory_xact_lock(505, (p_id % 2147483647)::INTEGER); END IF;
  -- Bloquea primero el salón: crear/reactivar una mesa no puede competir con su baja.
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_anterior FROM ven_mesa WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN RETURN json_build_object('registro', NULL); END IF;
  END IF;
  PERFORM 1 FROM ven_salon WHERE id IN (v_anterior.id_salon, (p_d->>'id_salon')::BIGINT) ORDER BY id FOR UPDATE;
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_anterior FROM ven_mesa WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN RETURN json_build_object('registro', NULL); END IF;
    -- Reasignar a otro salón se permite solo cuando la mesa está libre/inhabilitada.
    IF v_anterior.estado_mesa IN (2,3) OR EXISTS (
      SELECT 1 FROM ven_pedido WHERE id_mesa = p_id AND estado = 1 AND estado_pedido IN (1,2,3)
    ) THEN RETURN json_build_object('error', 'La mesa tiene atención en curso; cierre el pedido antes de modificarla'); END IF;
  END IF;
  v := jsonb_populate_record(v_anterior, p_d);
  v.codigo := upper(trim(v.codigo));
  v.capacidad_personas := COALESCE(v.capacidad_personas, 2);
  v.estado_mesa := COALESCE(v.estado_mesa, 1);
  IF COALESCE(v.codigo, '') = '' OR v.capacidad_personas NOT BETWEEN 1 AND 100 THEN
    RETURN json_build_object('error', 'Código obligatorio y capacidad entre 1 y 100 personas');
  END IF;
  -- Ocupada / por cobrar pertenecen al flujo de pedidos, no al mantenimiento.
  IF v.estado_mesa NOT IN (1,4) THEN
    RETURN json_build_object('error', 'Solo se puede habilitar o inhabilitar la mesa; ocupada y por cobrar se asignan desde pedidos');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ven_salon s JOIN gen_sucursal g ON g.id = s.id_sucursal WHERE s.id = v.id_salon AND s.estado = 1 AND g.estado = 1) THEN
    RETURN json_build_object('error', 'El salón o su sucursal no existen o están inactivos');
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO ven_mesa (id_salon, codigo, capacidad_personas, estado_mesa, id_usuario_creacion, id_usuario_modificacion)
    VALUES (v.id_salon, v.codigo, v.capacidad_personas, v.estado_mesa, p_usuario, p_usuario) RETURNING id INTO p_id;
  ELSE
    UPDATE ven_mesa SET id_salon = v.id_salon, codigo = v.codigo, capacidad_personas = v.capacidad_personas,
      estado_mesa = v.estado_mesa, id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = p_id;
  END IF;
  RETURN ven_obtener_mesa(p_id);
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('error', 'Ya existe una mesa con ese código en el salón (incluso inactiva)');
END;
$$;
