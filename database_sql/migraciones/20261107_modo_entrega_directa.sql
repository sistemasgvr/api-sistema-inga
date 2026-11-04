-- Modo de entrega por empresa.
--
--   0 = flujo con comandas (actual): al comandar el plato queda "enviado";
--       cocina inicia preparación y marca "plato listo" antes de que el mozo
--       pueda entregarlo.
--   1 = entrega directa: al comandar el plato queda "por entregar" y cocina lo ve
--       solo como pantalla informativa. La entrega descuenta primero el plato ya
--       preparado y, por lo que falte, los insumos apartados al comandar
--       (backflush): no hace falta registrar la producción.
--
-- Reejecutable: la columna y el CHECK se crean solo si no existen.
ALTER TABLE gen_empresa
    ADD COLUMN IF NOT EXISTS modo_entrega_directa SMALLINT NOT NULL DEFAULT 0;

DO $mig$ BEGIN
    ALTER TABLE gen_empresa
        ADD CONSTRAINT ck_gen_empresa_modo_entrega
        CHECK (modo_entrega_directa IN (0, 1));
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
