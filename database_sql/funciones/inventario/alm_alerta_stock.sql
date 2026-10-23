-- Alerta de stock mínimo consolidada por producto (suma de todos sus almacenes).
-- Solo avisa cuando el nivel empeora (normal → bajo → agotado), así una venta tras
-- otra no repite el aviso; al reponer, el nivel vuelve a normal y queda listo para avisar de nuevo.
-- La notificación queda pendiente y el despachador del backend la envía por socket.
CREATE OR REPLACE FUNCTION public.alm_alerta_stock()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_actual NUMERIC; v_minimo NUMERIC; v_nivel SMALLINT; v_previo SMALLINT;
  v_nombre TEXT; v_simbolo TEXT;
BEGIN
  IF NEW.stock_actual IS NOT DISTINCT FROM OLD.stock_actual
     AND NEW.stock_minimo IS NOT DISTINCT FROM OLD.stock_minimo
     AND NEW.estado IS NOT DISTINCT FROM OLD.estado THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(SUM(stock_actual), 0), COALESCE(SUM(stock_minimo), 0)
  INTO v_actual, v_minimo
  FROM alm_producto_stock
  WHERE id_producto = NEW.id_producto AND estado = 1;

  -- Solo los productos que tienen stock mínimo configurado.
  v_nivel := CASE WHEN v_minimo <= 0 THEN 0
                  WHEN v_actual <= 0 THEN 2
                  WHEN v_actual <= v_minimo THEN 1
                  ELSE 0 END;

  INSERT INTO alm_alerta_stock_estado (id_producto, nivel)
  VALUES (NEW.id_producto, 0)
  ON CONFLICT (id_producto) DO NOTHING;

  SELECT nivel INTO v_previo FROM alm_alerta_stock_estado
  WHERE id_producto = NEW.id_producto FOR UPDATE;

  IF v_nivel = v_previo THEN RETURN NULL; END IF;

  UPDATE alm_alerta_stock_estado SET nivel = v_nivel, fecha_modificacion = now()
  WHERE id_producto = NEW.id_producto;

  IF v_nivel < v_previo THEN RETURN NULL; END IF;

  SELECT p.nombre, um.simbolo INTO v_nombre, v_simbolo
  FROM pro_producto p
  LEFT JOIN pro_unidad_medida um ON um.id = p.id_unidad_medida
  WHERE p.id = NEW.id_producto AND p.estado = 1;

  IF v_nombre IS NULL THEN RETURN NULL; END IF;

  PERFORM not_crear(
    'inventario',
    CASE WHEN v_nivel = 2 THEN 'Producto agotado: ' ELSE 'Stock bajo: ' END || v_nombre,
    CASE WHEN v_nivel = 2
      THEN 'Sin stock disponible (mínimo ' || trim_scale(v_minimo) || COALESCE(' ' || v_simbolo, '') || ').'
      ELSE 'Quedan ' || trim_scale(v_actual) || COALESCE(' ' || v_simbolo, '') ||
           ' (mínimo ' || trim_scale(v_minimo) || COALESCE(' ' || v_simbolo, '') || ').'
    END,
    CASE WHEN v_nivel = 2 THEN 'error' ELSE 'warning' END,
    '/productos/stock?estado=alertas&buscar=' || not_parametro_url(v_nombre),
    NEW.id_producto,
    NULL,
    NULL,
    jsonb_build_object('id_producto', NEW.id_producto, 'stock_actual', v_actual, 'stock_minimo', v_minimo),
    FALSE
  );
  RETURN NULL;
END; $$;

DROP TRIGGER IF EXISTS alm_trg_alerta_stock ON alm_producto_stock;
CREATE TRIGGER alm_trg_alerta_stock
  AFTER UPDATE OF stock_actual, stock_minimo, estado ON alm_producto_stock
  FOR EACH ROW EXECUTE FUNCTION public.alm_alerta_stock();
