-- Multiempresa, fase 2: empresa, SUNAT y numeración por empresa. Re-ejecutable.
--
-- Reglas: la numeración de comprobantes (series y correlativos) y de resúmenes y
-- bajas SUNAT es por empresa (RUC), compartida entre sus sucursales. Los
-- comprobantes guardan su empresa para que bandeja, resúmenes y tickets no
-- dependan de «la empresa activa». Las empresas se crean en la base de datos y
-- reciben sus series B001, F001 y NV01 automáticamente.
BEGIN;

-- ---------------------------------------------------------------------------
-- Series y correlativos por empresa
-- ---------------------------------------------------------------------------
ALTER TABLE gen_correlativo ADD COLUMN IF NOT EXISTS id_empresa BIGINT;

-- Datos existentes: la empresa de la sucursal que tenía la serie.
UPDATE gen_correlativo c
SET id_empresa = s.id_empresa
FROM gen_sucursal s
WHERE s.id = c.id_sucursal
  AND c.id_empresa IS NULL;

-- id_sucursal queda como dato histórico; ya no participa en la numeración.
ALTER TABLE gen_correlativo ALTER COLUMN id_sucursal DROP NOT NULL;

DO $mig$ BEGIN
    ALTER TABLE gen_correlativo
        ADD CONSTRAINT fk_gen_correlativo_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- Varias sucursales de la misma empresa podían tener la misma serie: se conserva
-- una fila por empresa y tipo, con el mayor correlativo usado.
UPDATE gen_correlativo c
SET ultimo_numero = m.ultimo
FROM (
    SELECT id_empresa, tipo_documento, serie, MAX(ultimo_numero) AS ultimo
    FROM gen_correlativo
    WHERE id_empresa IS NOT NULL
    GROUP BY id_empresa, tipo_documento, serie
) m
WHERE c.id_empresa = m.id_empresa
  AND c.tipo_documento = m.tipo_documento
  AND c.serie = m.serie;

DELETE FROM gen_correlativo c
USING (
    SELECT id
    FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY id_empresa, tipo_documento, serie
                   ORDER BY id
               ) AS orden
        FROM gen_correlativo
        WHERE id_empresa IS NOT NULL
    ) d
    WHERE d.orden > 1
) x
WHERE c.id = x.id;

ALTER TABLE gen_correlativo DROP CONSTRAINT IF EXISTS uq_gen_correlativo;
DO $mig$ BEGIN
    ALTER TABLE gen_correlativo
        ADD CONSTRAINT uq_gen_correlativo_empresa
        UNIQUE (id_empresa, tipo_documento, serie);
EXCEPTION WHEN duplicate_object THEN NULL;
         WHEN duplicate_table THEN NULL;
END $mig$;

DO $mig$ BEGIN
    IF EXISTS (SELECT 1 FROM gen_correlativo WHERE id_empresa IS NULL) THEN
        RAISE EXCEPTION 'Hay series sin empresa: complete gen_correlativo.id_empresa antes de continuar';
    END IF;
    ALTER TABLE gen_correlativo ALTER COLUMN id_empresa SET NOT NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- Comprobantes: empresa del pedido
-- ---------------------------------------------------------------------------
ALTER TABLE ven_comprobante ADD COLUMN IF NOT EXISTS id_empresa BIGINT;

UPDATE ven_comprobante c
SET id_empresa = s.id_empresa
FROM ven_pedido p
INNER JOIN gen_sucursal s ON s.id = p.id_sucursal
WHERE p.id = c.id_pedido
  AND c.id_empresa IS NULL;

-- Respaldo para bases con una sola empresa activa (datos incompletos antiguos).
UPDATE ven_comprobante
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;

DO $mig$ BEGIN
    ALTER TABLE ven_comprobante
        ADD CONSTRAINT fk_ven_comprobante_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

ALTER TABLE ven_comprobante DROP CONSTRAINT IF EXISTS uq_ven_comprobante;
DO $mig$ BEGIN
    ALTER TABLE ven_comprobante
        ADD CONSTRAINT uq_ven_comprobante_empresa
        UNIQUE (id_empresa, serie, correlativo, tipo_comprobante);
EXCEPTION WHEN duplicate_object THEN NULL;
         WHEN duplicate_table THEN NULL;
END $mig$;

DO $mig$ BEGIN
    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_empresa IS NULL) THEN
        RAISE EXCEPTION 'Hay comprobantes sin empresa: revise ven_pedido.id_sucursal o complete ven_comprobante.id_empresa';
    END IF;
    ALTER TABLE ven_comprobante ALTER COLUMN id_empresa SET NOT NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- Resúmenes diarios y comunicaciones de baja: empresa
-- ---------------------------------------------------------------------------
ALTER TABLE ven_sunat_lote ADD COLUMN IF NOT EXISTS id_empresa BIGINT;

UPDATE ven_sunat_lote l
SET id_empresa = (
    SELECT c.id_empresa
    FROM ven_sunat_lote_detalle d
    INNER JOIN ven_comprobante c ON c.id = d.id_comprobante
    WHERE d.id_lote = l.id
    ORDER BY d.id
    LIMIT 1
)
WHERE l.id_empresa IS NULL;

UPDATE ven_sunat_lote
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;

DO $mig$ BEGIN
    ALTER TABLE ven_sunat_lote
        ADD CONSTRAINT fk_ven_sunat_lote_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

ALTER TABLE ven_sunat_lote DROP CONSTRAINT IF EXISTS uq_ven_sunat_lote;
DO $mig$ BEGIN
    ALTER TABLE ven_sunat_lote
        ADD CONSTRAINT uq_ven_sunat_lote_empresa
        UNIQUE (id_empresa, tipo_lote, fecha_envio, correlativo);
EXCEPTION WHEN duplicate_object THEN NULL;
         WHEN duplicate_table THEN NULL;
END $mig$;

DO $mig$ BEGIN
    IF EXISTS (SELECT 1 FROM ven_sunat_lote WHERE id_empresa IS NULL) THEN
        RAISE EXCEPTION 'Hay resúmenes o bajas sin empresa: complete ven_sunat_lote.id_empresa';
    END IF;
    ALTER TABLE ven_sunat_lote ALTER COLUMN id_empresa SET NOT NULL;
END $mig$;

COMMIT;

-- ---------------------------------------------------------------------------
-- Funciones
-- ---------------------------------------------------------------------------
\ir ../funciones/general/empresa/gen_crear_series_empresa.sql
\ir ../funciones/general/empresa/gen_empresa_crear_series.sql
\ir ../funciones/general/empresa/gen_obtener_empresa.sql
\ir ../funciones/general/empresa/gen_guardar_empresa.sql
\ir ../funciones/general/empresa/gen_guardar_logo_empresa.sql
\ir ../funciones/sunat/configuracion/gen_obtener_configuracion_sunat.sql
\ir ../funciones/sunat/configuracion/gen_guardar_configuracion_sunat.sql
\ir ../funciones/sunat/configuracion/gen_guardar_certificado_sunat.sql
\ir ../funciones/sunat/configuracion/gen_obtener_emisor_sunat.sql
\ir ../funciones/sunat/configuracion/gen_listar_empresas_sunat_activas.sql
\ir ../funciones/ventas/ven_sunat_fecha_limite.sql
\ir ../funciones/sunat/comprobantes/ven_sunat_obtener_comprobantes.sql
\ir ../funciones/sunat/comprobantes/ven_sunat_comprobante_vigente.sql
\ir ../funciones/sunat/comprobantes/ven_sunat_listar_vencidos.sql
\ir ../funciones/sunat/comprobantes/ven_sunat_resumen_por_vencer.sql
\ir ../funciones/sunat/comprobantes/ven_sunat_listar_comprobantes_dia.sql
\ir ../funciones/sunat/comprobantes/ven_sunat_listar_bandeja.sql
\ir ../funciones/sunat/lotes/ven_sunat_crear_lote.sql
\ir ../funciones/sunat/lotes/ven_sunat_listar_lotes.sql
\ir ../funciones/sunat/lotes/ven_sunat_obtener_lote.sql
\ir ../funciones/sunat/lotes/ven_sunat_listar_lotes_en_proceso.sql
\ir ../funciones/pedidos/ven_pedido_cobrar.sql
\ir ../funciones/ventas/ven_reemitir_comprobante.sql
\ir ../funciones/ventas/ven_ticket_comprobante.sql

-- Empresas que ya existían: sus series por empresa (no duplica las que ya tienen).
DO $mig$ DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id FROM gen_empresa LOOP
        PERFORM gen_crear_series_empresa(r.id);
    END LOOP;
END $mig$;

-- Cliente genérico para boletas sin DNI y notas de venta.
INSERT INTO cli_persona (tipo_persona, tipo_documento, num_documento, razon_social, nombres, es_cliente)
VALUES (1, 1, '00000000', 'CLIENTES VARIOS', 'CLIENTES VARIOS', TRUE)
ON CONFLICT ON CONSTRAINT uq_cli_persona_doc DO UPDATE SET es_cliente = TRUE, estado = 1;
