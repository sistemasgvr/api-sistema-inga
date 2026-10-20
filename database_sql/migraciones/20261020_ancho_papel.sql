BEGIN;

-- Ancho del rollo de cada impresora: define las columnas del ticket (58 mm → 32, 80 mm → 48)
-- y el ancho del PDF archivado. Por defecto 80 mm, el rollo más común en caja y cocina.
ALTER TABLE gen_estacion ADD COLUMN IF NOT EXISTS ancho_papel SMALLINT NOT NULL DEFAULT 80;
DO $$ BEGIN
  ALTER TABLE gen_estacion ADD CONSTRAINT ck_estacion_ancho_papel CHECK (ancho_papel IN (58, 80));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMIT;

\ir ../funciones/general/estaciones/gen_listar_estaciones.sql
\ir ../funciones/general/estaciones/gen_obtener_estacion.sql
