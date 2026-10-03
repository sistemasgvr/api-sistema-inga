BEGIN;

-- Sólo las comandas creadas después de instalar esta migración se encolan.
CREATE TABLE IF NOT EXISTS ven_impresion_trabajo (
  id_comanda BIGINT PRIMARY KEY REFERENCES ven_comanda(id),
  id_estacion BIGINT NOT NULL REFERENCES gen_estacion(id),
  contenido JSONB NOT NULL,
  estado TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente','procesando','enviado','revision')),
  propietario UUID,
  intentos INTEGER NOT NULL DEFAULT 0,
  error TEXT,
  actualizado TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_impresion_pendientes
  ON ven_impresion_trabajo(id_estacion, id_comanda) WHERE estado = 'pendiente';

CREATE OR REPLACE FUNCTION ven_encolar_impresion() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE pedido JSONB;
BEGIN
  -- Diferido al COMMIT: los detalles ya tienen su id_comanda y quedan congelados.
  pedido := (ven_obtener_pedido(NEW.id_pedido)::JSONB)->'registro';
  INSERT INTO ven_impresion_trabajo(id_comanda,id_estacion,contenido)
  SELECT NEW.id,NEW.id_estacion,jsonb_build_object(
    'id',NEW.id::TEXT,'numero',NEW.numero,'pedido',pedido->>'codigo',
    'mesa',pedido->>'codigo_mesa','mozo',pedido->>'nombre_mozo',
    'tipo_pedido',pedido->'tipo_pedido','observacion',pedido->>'observacion',
    'fecha',NEW.fecha_envio,'estacion',e.nombre,
    'items',COALESCE((SELECT jsonb_agg(x) FROM jsonb_array_elements(pedido->'items') x
      WHERE x->>'id_comanda' = NEW.id::TEXT),'[]'::JSONB))
  FROM gen_estacion e WHERE e.id=NEW.id_estacion
  ON CONFLICT(id_comanda) DO NOTHING;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS tr_encolar_impresion ON ven_comanda;
CREATE CONSTRAINT TRIGGER tr_encolar_impresion AFTER INSERT ON ven_comanda
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION ven_encolar_impresion();
COMMIT;
