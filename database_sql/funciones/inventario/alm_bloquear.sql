-- Bloqueo transaccional único de inventario: simplifica el orden de bloqueo entre
-- producción (varios productos), reservas y traslados. Los pedidos se bloquean antes.
CREATE OR REPLACE FUNCTION alm_bloquear() RETURNS VOID LANGUAGE sql AS $$
  SELECT pg_advisory_xact_lock(74123,1);
$$;
