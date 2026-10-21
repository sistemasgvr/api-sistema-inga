-- Vuelve a poner una comanda (o precuenta) en la cola de impresión de su estación.
--
-- El trabajo de impresión se identifica por id_comanda: si ya existe se reinicia
-- a 'pendiente' con el mismo contenido y la marca de reimpresión; si la comanda
-- es anterior a la cola de impresión, se arma igual que ven_encolar_impresion.
CREATE OR REPLACE FUNCTION ven_reimprimir_comanda(p_id_comanda BIGINT, p_usuario BIGINT)
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE c ven_comanda%ROWTYPE; pedido JSONB;
BEGIN
  SELECT * INTO c FROM ven_comanda WHERE id = p_id_comanda AND estado = 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'La comanda no existe' USING ERRCODE = 'P0002'; END IF;
  IF NOT EXISTS(SELECT 1 FROM gen_estacion e WHERE e.id = c.id_estacion AND e.estado = 1) THEN
    RAISE EXCEPTION 'La estación de esta comanda está desactivada';
  END IF;

  -- La precuenta se rearma con los consumos vigentes (sin platos cancelados
  -- después de pedirla) y se descarta su PDF archivado.
  UPDATE ven_impresion_trabajo
  SET estado = 'pendiente', propietario = NULL, intentos = 0, error = NULL, actualizado = CURRENT_TIMESTAMP,
      contenido = contenido || jsonb_build_object('reimpresion', TRUE)
        || CASE WHEN contenido->>'tipo' = 'PRECUENTA' THEN ven_contenido_precuenta(c.id_pedido) ELSE '{}'::JSONB END,
      ruta_pdf = CASE WHEN contenido->>'tipo' = 'PRECUENTA' THEN NULL ELSE ruta_pdf END
  WHERE id_comanda = c.id;

  IF NOT FOUND THEN
    pedido := (ven_obtener_pedido(c.id_pedido)::JSONB)->'registro';
    INSERT INTO ven_impresion_trabajo(id_comanda, id_estacion, contenido)
    SELECT c.id, c.id_estacion, jsonb_build_object(
      'id', c.id::TEXT, 'numero', c.numero, 'pedido', pedido->>'codigo',
      'mesa', pedido->>'codigo_mesa', 'mozo', pedido->>'nombre_mozo',
      'tipo_pedido', pedido->'tipo_pedido', 'observacion', pedido->>'observacion',
      'fecha', c.fecha_envio, 'estacion', e.nombre, 'reimpresion', TRUE,
      'items', COALESCE((SELECT jsonb_agg(x) FROM jsonb_array_elements(pedido->'items') x
        WHERE x->>'id_comanda' = c.id::TEXT), '[]'::JSONB))
    FROM gen_estacion e WHERE e.id = c.id_estacion;
  END IF;

  RETURN ven_obtener_venta(c.id_pedido);
END;
$$;
