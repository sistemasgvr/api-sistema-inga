-- Ventas = pedidos cobrados (estado_pedido 4), uno por fila.
--
-- Se lista por pedido y no por comprobante porque las ventas a crédito del
-- consorcio no tienen comprobante, y un pedido puede tener varios comprobantes
-- si se reemitió. El comprobante vigente va como columna y el buscador también
-- encuentra la venta por su número (B001-00000002).
--
-- Filtros (p_f): buscar, fecha_desde, fecha_hasta (fecha de cobro en Lima),
-- tipo_comprobante (0 = sin comprobante), medio_pago, id_caja, limite, offset.
CREATE OR REPLACE FUNCTION ven_listar_ventas(p_f JSONB)
RETURNS JSON LANGUAGE sql STABLE AS $$
  WITH medios AS (
    SELECT o.valor_entero AS medio_pago, o.nombre
    FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = 'MEDIO_PAGO'
  ), vigente AS (
    SELECT DISTINCT ON (c.id_pedido) c.id_pedido, c.id, c.tipo_comprobante, c.serie, c.correlativo,
      c.receptor_num_doc, c.receptor_razon_social
    FROM ven_comprobante c WHERE c.estado = 1
    ORDER BY c.id_pedido, c.id DESC
  ), filtrados AS (
    SELECT p.*, v.id AS id_comprobante, v.tipo_comprobante, v.serie, v.correlativo,
      v.receptor_num_doc, v.receptor_razon_social
    FROM ven_pedido p
    LEFT JOIN vigente v ON v.id_pedido = p.id
    WHERE p.estado = 1 AND p.estado_pedido = 4
      AND (NULLIF(p_f->>'fecha_desde', '') IS NULL
        OR (p.fecha_cierre AT TIME ZONE 'America/Lima')::DATE >= (p_f->>'fecha_desde')::DATE)
      AND (NULLIF(p_f->>'fecha_hasta', '') IS NULL
        OR (p.fecha_cierre AT TIME ZONE 'America/Lima')::DATE <= (p_f->>'fecha_hasta')::DATE)
      AND (NULLIF(p_f->>'tipo_comprobante', '') IS NULL
        OR COALESCE(v.tipo_comprobante, 0) = (p_f->>'tipo_comprobante')::INTEGER)
      AND (NULLIF(p_f->>'medio_pago', '') IS NULL OR EXISTS(
        SELECT 1 FROM ven_pago g WHERE g.id_pedido = p.id AND g.estado = 1
          AND g.medio_pago = (p_f->>'medio_pago')::INTEGER))
      AND (NULLIF(p_f->>'id_caja', '') IS NULL OR EXISTS(
        SELECT 1 FROM ven_pago g JOIN caj_turno t ON t.id = g.id_turno
        WHERE g.id_pedido = p.id AND g.estado = 1 AND t.id_caja = (p_f->>'id_caja')::BIGINT))
      AND (COALESCE(p_f->>'buscar', '') = ''
        OR p.codigo ILIKE '%' || (p_f->>'buscar') || '%'
        OR (v.serie || '-' || v.correlativo) ILIKE '%' || (p_f->>'buscar') || '%'
        OR v.receptor_num_doc ILIKE '%' || (p_f->>'buscar') || '%'
        OR v.receptor_razon_social ILIKE '%' || (p_f->>'buscar') || '%'
        OR EXISTS(SELECT 1 FROM cli_persona c WHERE c.id = p.id_persona AND (
          concat_ws(' ', c.nombres, c.apellido_paterno, c.apellido_materno, c.razon_social) ILIKE '%' || (p_f->>'buscar') || '%'
          OR c.num_documento ILIKE '%' || (p_f->>'buscar') || '%')))
  ), pagina AS (
    SELECT f.id, f.codigo, f.tipo_pedido, f.id_sucursal, f.monto_total, f.fecha_apertura, f.fecha_cierre,
      (SELECT m.codigo FROM ven_mesa m WHERE m.id = f.id_mesa) AS codigo_mesa,
      (SELECT trim(concat_ws(' ', u.nombres, u.apellidos)) FROM auth_usuario_datos u WHERE u.id = f.id_mozo) AS nombre_mozo,
      (SELECT COALESCE(NULLIF(trim(concat_ws(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''), c.razon_social)
        FROM cli_persona c WHERE c.id = f.id_persona) AS nombre_cliente,
      f.id_comprobante, f.tipo_comprobante,
      CASE WHEN f.id_comprobante IS NOT NULL THEN f.serie || '-' || f.correlativo END AS numero_comprobante,
      f.receptor_num_doc, f.receptor_razon_social,
      (SELECT count(*) > 1 FROM ven_comprobante c WHERE c.id_pedido = f.id) AS reemitido,
      COALESCE((SELECT json_agg(json_build_object('id', g.id, 'medio_pago', g.medio_pago,
          'nombre_medio', COALESCE(m.nombre, g.medio_pago::TEXT), 'monto', g.monto) ORDER BY g.id)
        FROM ven_pago g LEFT JOIN medios m ON m.medio_pago = g.medio_pago
        WHERE g.id_pedido = f.id AND g.estado = 1), '[]'::JSON) AS pagos,
      (SELECT string_agg(DISTINCT cj.nombre, ', ') FROM ven_pago g
        JOIN caj_turno t ON t.id = g.id_turno JOIN caj_caja cj ON cj.id = t.id_caja
        WHERE g.id_pedido = f.id AND g.estado = 1) AS cajas,
      EXISTS(SELECT 1 FROM ven_pago g JOIN caj_turno t ON t.id = g.id_turno
        WHERE g.id_pedido = f.id AND g.estado = 1 AND t.estado_turno = 2) AS caja_cerrada
    FROM filtrados f
    ORDER BY f.fecha_cierre DESC NULLS LAST, f.id DESC
    LIMIT COALESCE((p_f->>'limite')::INTEGER, 10) OFFSET COALESCE((p_f->>'offset')::INTEGER, 0)
  )
  SELECT json_build_object(
    'registros', COALESCE((SELECT json_agg(p) FROM pagina p), '[]'::JSON),
    'total', (SELECT count(*) FROM filtrados),
    'resumen', json_build_object(
      'cantidad', (SELECT count(*) FROM filtrados),
      'monto_total', (SELECT COALESCE(sum(monto_total), 0) FROM filtrados),
      'por_medio', COALESCE((SELECT json_agg(x ORDER BY x.medio_pago) FROM (
        SELECT g.medio_pago, COALESCE(m.nombre, g.medio_pago::TEXT) AS nombre_medio, sum(g.monto) AS monto
        FROM ven_pago g JOIN filtrados f ON f.id = g.id_pedido LEFT JOIN medios m ON m.medio_pago = g.medio_pago
        WHERE g.estado = 1 GROUP BY g.medio_pago, m.nombre) x), '[]'::JSON)));
$$;
