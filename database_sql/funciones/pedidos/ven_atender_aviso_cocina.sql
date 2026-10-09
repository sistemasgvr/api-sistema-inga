CREATE OR REPLACE FUNCTION ven_atender_aviso_cocina(p_id BIGINT,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE aviso ven_aviso_cocina%ROWTYPE;
BEGIN
  UPDATE ven_aviso_cocina SET estado=2,fecha_atencion=CURRENT_TIMESTAMP,id_usuario_atencion=p_usuario,
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
    WHERE id=p_id AND estado=1 RETURNING * INTO aviso;
  IF NOT FOUND THEN
    SELECT * INTO aviso FROM ven_aviso_cocina WHERE id=p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Aviso no encontrado' USING ERRCODE='P0002'; END IF;
  END IF;
  RETURN json_build_object('registro',to_jsonb(aviso));
END $$;
