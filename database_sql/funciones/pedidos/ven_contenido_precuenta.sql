-- Datos de la precuenta con los consumos vigentes del pedido: excluye las líneas
-- canceladas y descuenta las cancelaciones parciales. Se arma en cada envío o
-- reimpresión para no imprimir una foto vieja del pedido.
CREATE OR REPLACE FUNCTION ven_contenido_precuenta(p_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE v ven_pedido%ROWTYPE; detalle JSONB;
BEGIN
  SELECT * INTO v FROM ven_pedido WHERE id=p_id;
  detalle:=(ven_obtener_pedido(p_id)::JSONB)->'registro';
  RETURN jsonb_build_object('pedido',v.codigo,'mesa',detalle->>'codigo_mesa','mozo',detalle->>'nombre_mozo',
    'tipo_pedido',v.tipo_pedido,'fecha',CURRENT_TIMESTAMP,'total',v.monto_total,
    'items',COALESCE((SELECT jsonb_agg(x || jsonb_build_object('cantidad',
      (x->>'cantidad')::NUMERIC-COALESCE((x->>'cantidad_cancelada')::NUMERIC,0))) FROM jsonb_array_elements(detalle->'items') x
      WHERE (x->>'tipo_linea')::INTEGER<>3 AND (x->>'cantidad')::NUMERIC>COALESCE((x->>'cantidad_cancelada')::NUMERIC,0)),'[]'::JSONB));
END $$;
