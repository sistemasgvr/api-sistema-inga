CREATE OR REPLACE FUNCTION public.ven_recalcular_pedido(p_id BIGINT, p_usuario BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_tasa NUMERIC; v_base NUMERIC; v_total NUMERIC;
BEGIN
  SELECT tasa_igv / 100 INTO v_tasa FROM ven_pedido WHERE id = p_id;
  UPDATE ven_pedido_detalle d SET monto_subtotal = CASE WHEN tipo_linea IN (2,3) THEN 0 ELSE
    round(cantidad * (precio_unitario + COALESCE((SELECT sum(a.precio_adicional)
      FROM ven_pedido_detalle_adicional a WHERE a.id_pedido_detalle = d.id AND a.estado = 1), 0)) - monto_descuento, 2) END
  WHERE id_pedido = p_id AND estado = 1;
  -- afecto_igv expresa si el precio del catálogo incluye IGV según la regla acordada.
  SELECT COALESCE(sum(CASE WHEN afecto_igv THEN round(monto_subtotal / (1 + v_tasa), 2) ELSE monto_subtotal END),0),
    COALESCE(sum(CASE WHEN afecto_igv THEN monto_subtotal ELSE round(monto_subtotal * (1 + v_tasa),2) END),0)
  INTO v_base, v_total FROM ven_pedido_detalle WHERE id_pedido = p_id AND estado = 1 AND tipo_linea <> 3;
  UPDATE ven_pedido SET monto_subtotal = v_base, monto_igv = v_total - v_base, monto_total = v_total,
    monto_descuento = COALESCE((SELECT sum(monto_descuento) FROM ven_pedido_detalle WHERE id_pedido = p_id AND estado = 1 AND tipo_linea = 1),0),
    id_usuario_modificacion = p_usuario, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = p_id;
END;
$$;
