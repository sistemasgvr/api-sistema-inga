CREATE OR REPLACE FUNCTION alm_proteger_historial() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE estado_mov SMALLINT;
BEGIN
  IF TG_TABLE_NAME='alm_movimiento' THEN
    IF OLD.estado=2 THEN RAISE EXCEPTION 'El movimiento confirmado es inmutable'; END IF;
  ELSE
    SELECT estado INTO estado_mov FROM alm_movimiento WHERE id=OLD.id_movimiento FOR UPDATE;
    IF estado_mov=2 THEN RAISE EXCEPTION 'El detalle confirmado es inmutable'; END IF;
    IF TG_OP='UPDATE' THEN
      SELECT estado INTO estado_mov FROM alm_movimiento WHERE id=NEW.id_movimiento FOR UPDATE;
      IF estado_mov=2 THEN RAISE EXCEPTION 'No se puede mover detalle a un movimiento confirmado'; END IF;
    END IF;
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  NEW.fecha_modificacion:=CURRENT_TIMESTAMP;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tr_alm_mov_historial ON alm_movimiento;
CREATE TRIGGER tr_alm_mov_historial BEFORE UPDATE OR DELETE ON alm_movimiento FOR EACH ROW EXECUTE FUNCTION alm_proteger_historial();
DROP TRIGGER IF EXISTS tr_alm_det_historial ON alm_movimiento_detalle;
CREATE TRIGGER tr_alm_det_historial BEFORE UPDATE OR DELETE ON alm_movimiento_detalle FOR EACH ROW EXECUTE FUNCTION alm_proteger_historial();
