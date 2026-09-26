CREATE OR REPLACE FUNCTION public.ven_obtener_pedido(p_id BIGINT)
RETURNS JSON LANGUAGE sql AS $$
  SELECT json_build_object('registro', (
    SELECT to_jsonb(p) || jsonb_build_object(
      'items', COALESCE((SELECT jsonb_agg(to_jsonb(d) || jsonb_build_object(
        'nombre_producto', pr.nombre,
        'adicionales', COALESCE((SELECT jsonb_agg(to_jsonb(a) || jsonb_build_object('nombre', pa.nombre) ORDER BY a.id)
          FROM ven_pedido_detalle_adicional a JOIN pro_adicional pa ON pa.id = a.id_adicional
          WHERE a.id_pedido_detalle = d.id AND a.estado = 1), '[]'::JSONB)
      ) ORDER BY d.id) FROM ven_pedido_detalle d JOIN pro_producto pr ON pr.id = d.id_producto
        WHERE d.id_pedido = p.id AND d.estado = 1), '[]'::JSONB),
      'comandas', COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.id) FROM ven_comanda c WHERE c.id_pedido = p.id), '[]'::JSONB)
    ) FROM ven_pedido p WHERE p.id = p_id AND p.estado = 1
  ));
$$;
