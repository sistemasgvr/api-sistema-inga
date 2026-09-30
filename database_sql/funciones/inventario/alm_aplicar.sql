CREATE OR REPLACE FUNCTION alm_aplicar(p_codigo TEXT,p_tipo TEXT,p_motivo TEXT,p_documento TEXT,p_documento_id BIGINT,p_detalles JSONB,p_usuario BIGINT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE t BIGINT; m BIGINT; r JSON;
BEGIN
  SELECT o.id INTO t FROM gen_lista_opcion o JOIN gen_lista l ON l.id=o.id_lista WHERE l.codigo='ALM_TIPO_MOVIMIENTO' AND o.codigo=p_tipo;
  SELECT o.id INTO m FROM gen_lista_opcion o JOIN gen_lista l ON l.id=o.id_lista WHERE l.codigo='ALM_MOTIVO_MOVIMIENTO' AND o.codigo=p_motivo;
  r:=alm_registrar(jsonb_build_object('codigo',p_codigo,'id_tipo_movimiento',t,'id_motivo_movimiento',m,
    'documento_tipo',p_documento,'documento_id',p_documento_id,'detalles',p_detalles,'confirmar',true),p_usuario);
  RETURN (r->'registro'->>'id')::BIGINT;
END $$;
