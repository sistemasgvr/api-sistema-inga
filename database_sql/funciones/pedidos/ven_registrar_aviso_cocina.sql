-- Se invoca desde el backend DESPUÉS de que la comanda se revirtió por falta de stock (SQLSTATE IN001).
-- Reintentar la misma comanda actualiza el aviso pendiente del pedido en lugar de duplicarlo.
CREATE OR REPLACE FUNCTION ven_registrar_aviso_cocina(p_pedido BIGINT,p_mensaje TEXT,p_faltantes JSONB,p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; v_estaciones BIGINT[]; aviso ven_aviso_cocina%ROWTYPE;
BEGIN
  SELECT * INTO v FROM ven_pedido WHERE id=p_pedido AND estado=1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido no encontrado' USING ERRCODE='P0002'; END IF;
  IF jsonb_typeof(p_faltantes) IS DISTINCT FROM 'array' OR jsonb_array_length(p_faltantes)=0 THEN RAISE EXCEPTION 'Faltantes inválidos'; END IF;
  SELECT COALESCE(array_agg(DISTINCT e::BIGINT) FILTER (WHERE e IS NOT NULL),'{}') INTO v_estaciones
    FROM jsonb_array_elements(p_faltantes) f, jsonb_array_elements_text(COALESCE(f->'estaciones','[]')) e;
  UPDATE ven_aviso_cocina SET mensaje=p_mensaje,faltantes=p_faltantes,estaciones=v_estaciones,
    id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
    WHERE id_pedido=p_pedido AND estado=1 RETURNING * INTO aviso;
  IF NOT FOUND THEN
    INSERT INTO ven_aviso_cocina(id_sucursal,id_pedido,estaciones,mensaje,faltantes,id_usuario_creacion,id_usuario_modificacion)
      VALUES(v.id_sucursal,p_pedido,v_estaciones,p_mensaje,p_faltantes,p_usuario,p_usuario) RETURNING * INTO aviso;
  END IF;
  RETURN json_build_object('registro',to_jsonb(aviso));
END $$;
