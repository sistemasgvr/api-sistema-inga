CREATE OR REPLACE FUNCTION alm_cancelar(p_id BIGINT,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE m alm_movimiento%ROWTYPE;
BEGIN
  PERFORM alm_bloquear();
  SELECT * INTO m FROM alm_movimiento WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Movimiento no encontrado' USING ERRCODE='P0002'; END IF;
  IF m.estado=2 THEN RAISE EXCEPTION 'Un movimiento confirmado requiere otro movimiento de corrección'; END IF;
  IF m.estado=1 THEN
    UPDATE alm_movimiento SET estado=3,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP WHERE id=p_id RETURNING * INTO m;
  END IF;
  RETURN json_build_object('registro',to_jsonb(m));
END $$;
