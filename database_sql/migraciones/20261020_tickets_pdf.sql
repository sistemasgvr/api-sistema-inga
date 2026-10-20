BEGIN;

-- PDF archivados en Supabase Storage (ruta del objeto dentro del bucket).
-- ven_comprobante.ruta_pdf ya existía en el esquema; se usa para el comprobante.
ALTER TABLE ven_impresion_trabajo ADD COLUMN IF NOT EXISTS ruta_pdf TEXT;

COMMIT;

\ir ../funciones/ventas/ven_ticket_comprobante.sql
\ir ../funciones/ventas/ven_imprimir_comprobante.sql
