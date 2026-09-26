-- Ejecutar mediante instalar_pedidos.sql. Conserva el esquema y los datos existentes.
ALTER TABLE public.ven_pedido
  ADD COLUMN IF NOT EXISTS tasa_igv NUMERIC(5,2) NOT NULL DEFAULT 18 CHECK (tasa_igv BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
  ADD COLUMN IF NOT EXISTS id_usuario_autoriza BIGINT REFERENCES public.auth_usuario(id);

ALTER TABLE public.ven_pedido_detalle
  ADD COLUMN IF NOT EXISTS afecto_igv BOOLEAN,
  ADD COLUMN IF NOT EXISTS insumos_seleccionados BIGINT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT;
UPDATE public.ven_pedido_detalle d SET afecto_igv = p.afecto_igv
FROM public.pro_producto p WHERE p.id = d.id_producto AND d.afecto_igv IS NULL;
ALTER TABLE public.ven_pedido_detalle ALTER COLUMN afecto_igv SET DEFAULT TRUE;
ALTER TABLE public.ven_pedido_detalle ALTER COLUMN afecto_igv SET NOT NULL;
COMMENT ON COLUMN public.ven_pedido_detalle.afecto_igv IS
  'Regla comercial de pedidos: true = precio incluye IGV; false = se agrega IGV. Copia del producto al agregar.';

-- Si existen mesas con pedidos duplicados, corregir esos datos antes de instalar.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ven_pedido_mesa_en_curso
  ON public.ven_pedido(id_mesa)
  WHERE id_mesa IS NOT NULL AND estado = 1 AND estado_pedido IN (1,2,3);
-- En los reversos, documento_id identifica el movimiento original del kardex.
CREATE UNIQUE INDEX IF NOT EXISTS uq_alm_kardex_reverso_venta
  ON public.alm_kardex(documento_id)
  WHERE documento_tipo = 'ANULACION_VENTA' AND signo = 1;
CREATE INDEX IF NOT EXISTS ix_alm_kardex_pedido_detalle
  ON public.alm_kardex(documento_id) WHERE documento_tipo = 'PEDIDO_DETALLE';
