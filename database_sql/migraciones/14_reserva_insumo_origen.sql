ALTER TABLE ven_pedido_reserva_insumo ADD COLUMN IF NOT EXISTS id_producto_origen BIGINT REFERENCES pro_producto(id);
ALTER TABLE ven_pedido_reserva_insumo ADD COLUMN IF NOT EXISTS es_preparado BOOLEAN NOT NULL DEFAULT FALSE;

-- El mismo ingrediente puede apartarse para varios sub-platos de una misma línea.
DO $$
DECLARE c TEXT;
BEGIN
  FOR c IN SELECT con.conname FROM pg_constraint con
    WHERE con.conrelid='ven_pedido_reserva_insumo'::regclass AND con.contype='u'
  LOOP
    EXECUTE format('ALTER TABLE ven_pedido_reserva_insumo DROP CONSTRAINT %I',c);
  END LOOP;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_ven_reserva_insumo_origen
  ON ven_pedido_reserva_insumo(id_pedido_detalle,id_producto,id_almacen,(COALESCE(id_producto_origen,0)));
