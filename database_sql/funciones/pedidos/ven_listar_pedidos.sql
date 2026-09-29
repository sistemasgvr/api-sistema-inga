CREATE OR REPLACE FUNCTION public.ven_listar_pedidos(p_f JSONB)
RETURNS JSON LANGUAGE sql AS $$
  WITH filtrados AS (
    SELECT p.* FROM ven_pedido p
    WHERE p.estado = 1
      AND (NULLIF(p_f->>'id_sucursal', '') IS NULL OR p.id_sucursal = (p_f->>'id_sucursal')::BIGINT)
      -- tipos_pedido: lista separada por comas, ej. '2,3' (para llevar y delivery).
      AND (NULLIF(p_f->>'tipos_pedido', '') IS NULL
        OR p.tipo_pedido = ANY(string_to_array(p_f->>'tipos_pedido', ',')::INTEGER[]))
      -- en_curso: abierto, comandado o por cobrar.
      AND (COALESCE((p_f->>'en_curso')::BOOLEAN, FALSE) = FALSE OR p.estado_pedido IN (1,2,3))
      AND (COALESCE(p_f->>'buscar', '') = ''
        OR p.codigo ILIKE '%' || (p_f->>'buscar') || '%'
        OR p.observacion ILIKE '%' || (p_f->>'buscar') || '%')
  ), pagina AS (
    SELECT f.id, f.codigo, f.tipo_pedido, f.id_sucursal, f.id_mesa, f.id_mozo, f.estado_pedido,
      f.observacion, f.monto_total, f.fecha_apertura,
      (SELECT m.codigo FROM ven_mesa m WHERE m.id = f.id_mesa) AS codigo_mesa,
      f.id_persona,
      (SELECT COALESCE(NULLIF(trim(concat_ws(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''), c.razon_social)
        FROM cli_persona c WHERE c.id = f.id_persona) AS nombre_cliente,
      (SELECT c.telefono FROM cli_persona c WHERE c.id = f.id_persona) AS telefono_cliente,
      (SELECT trim(concat_ws(' ', u.nombres, u.apellidos)) FROM auth_usuario_datos u WHERE u.id = f.id_mozo) AS nombre_mozo,
      (SELECT count(*) FROM ven_pedido_detalle d WHERE d.id_pedido = f.id AND d.estado = 1 AND d.tipo_linea <> 3) AS cantidad_items
    FROM filtrados f ORDER BY f.fecha_apertura DESC, f.id DESC
    LIMIT COALESCE((p_f->>'limite')::INTEGER, 10) OFFSET COALESCE((p_f->>'offset')::INTEGER, 0)
  )
  SELECT json_build_object('registros', COALESCE((SELECT json_agg(p) FROM pagina p), '[]'::JSON),
    'total', (SELECT count(*) FROM filtrados));
$$;
