CREATE OR REPLACE FUNCTION alm_validar_insercion_detalle() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  PERFORM 1 FROM alm_movimiento WHERE id=NEW.id_movimiento AND estado=1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Solo se agregan detalles a borradores'; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tr_alm_det_insert ON alm_movimiento_detalle;
CREATE TRIGGER tr_alm_det_insert BEFORE INSERT ON alm_movimiento_detalle FOR EACH ROW EXECUTE FUNCTION alm_validar_insercion_detalle();
