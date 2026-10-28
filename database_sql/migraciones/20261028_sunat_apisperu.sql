-- Emisión electrónica SUNAT vía APIsPERU.
-- Re-ejecutable: agrega columnas, tablas, listas y funciones sin tocar datos existentes.
--
-- Flujo: al cobrar, la boleta/factura queda PENDIENTE con su fecha límite de envío
-- (fecha de emisión + días configurados por tipo). Se envía a mano desde Ventas o,
-- al llegar esa fecha, el programador del API la envía solo. La nota de venta no se envía.

BEGIN;

-- Tasa de IGV de la empresa: se copia a cada pedido al abrirlo (cambia según el régimen).
ALTER TABLE gen_empresa ADD COLUMN IF NOT EXISTS tasa_igv NUMERIC(5, 2) NOT NULL DEFAULT 18;
DO $mig$ BEGIN
  ALTER TABLE gen_empresa ADD CONSTRAINT ck_gen_empresa_tasa_igv CHECK (tasa_igv BETWEEN 0 AND 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- Credenciales (cifradas en el API) y plazos de envío. La empresa ya existe en APIsPERU:
-- aquí solo se guarda su token de emisión.
ALTER TABLE gen_configuracion_sunat
  ADD COLUMN IF NOT EXISTS token_emision_cifrado     TEXT,
  ADD COLUMN IF NOT EXISTS clave_certificado_cifrada TEXT,
  ADD COLUMN IF NOT EXISTS certificado_titular       VARCHAR(255),
  ADD COLUMN IF NOT EXISTS certificado_vence         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dias_limite_envio_boleta  SMALLINT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS dias_limite_envio_factura SMALLINT NOT NULL DEFAULT 7;
DO $mig$ BEGIN
  ALTER TABLE gen_configuracion_sunat ADD CONSTRAINT ck_gen_config_sunat_dias
    CHECK (dias_limite_envio_boleta BETWEEN 0 AND 30 AND dias_limite_envio_factura BETWEEN 0 AND 30);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- estado_sunat: 0 no aplica (nota de venta), 1 pendiente, 2 aceptado, 3 rechazado, 4 anulado, 5 en proceso.
-- forma_envio: 1 individual (/invoice/send), 2 resumen diario (/summary/send).
ALTER TABLE ven_comprobante
  ADD COLUMN IF NOT EXISTS fecha_limite_envio     DATE,
  ADD COLUMN IF NOT EXISTS forma_envio            SMALLINT,
  ADD COLUMN IF NOT EXISTS codigo_respuesta_sunat VARCHAR(10),
  ADD COLUMN IF NOT EXISTS observaciones_sunat    TEXT,
  ADD COLUMN IF NOT EXISTS ruta_cdr               TEXT,
  ADD COLUMN IF NOT EXISTS ruta_pdf_a4            TEXT,
  ADD COLUMN IF NOT EXISTS intentos_envio         INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fecha_envio_sunat      TIMESTAMPTZ;

-- Datos tributarios de cada línea, calculados al emitir (igual redondeo que ven_recalcular_pedido).
ALTER TABLE ven_comprobante_detalle
  ADD COLUMN IF NOT EXISTS id_producto         BIGINT,
  ADD COLUMN IF NOT EXISTS unidad_sunat        VARCHAR(5)     NOT NULL DEFAULT 'NIU',
  ADD COLUMN IF NOT EXISTS tipo_afectacion_igv VARCHAR(2)     NOT NULL DEFAULT '10',
  ADD COLUMN IF NOT EXISTS tasa_igv            NUMERIC(5, 2)  NOT NULL DEFAULT 18,
  ADD COLUMN IF NOT EXISTS valor_unitario      NUMERIC(22, 10),
  ADD COLUMN IF NOT EXISTS precio_unitario_igv NUMERIC(22, 10),
  ADD COLUMN IF NOT EXISTS monto_base_igv      NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS monto_igv           NUMERIC(12, 2);

-- Resúmenes diarios (RC) y comunicaciones de baja (RA). SUNAT los procesa en diferido:
-- devuelve un ticket que se consulta hasta tener el CDR.
-- tipo_lote: 1 resumen diario (RC), 2 comunicación de baja (RA).
CREATE TABLE IF NOT EXISTS ven_sunat_lote (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_lote               SMALLINT     NOT NULL,
    fecha_documentos        DATE         NOT NULL,
    fecha_envio             DATE         NOT NULL,
    correlativo             INTEGER      NOT NULL,
    identificador           VARCHAR(30)  NOT NULL,
    ticket                  VARCHAR(60),
    estado_sunat            SMALLINT     NOT NULL DEFAULT 1,
    codigo_respuesta_sunat  VARCHAR(10),
    sunat_mensaje           TEXT,
    ruta_xml                TEXT,
    ruta_cdr                TEXT,
    intentos_consulta       INTEGER      NOT NULL DEFAULT 0,
    fecha_consulta          TIMESTAMPTZ,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_ven_sunat_lote_tipo CHECK (tipo_lote IN (1, 2)),
    CONSTRAINT uq_ven_sunat_lote UNIQUE (tipo_lote, fecha_envio, correlativo),
    CONSTRAINT fk_ven_sunat_lote_usr_creacion FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuario (id) ON DELETE SET NULL,
    CONSTRAINT fk_ven_sunat_lote_usr_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuario (id) ON DELETE SET NULL
);

-- estado_item (catálogo SUNAT 19): 1 adicionar, 3 anular. En una baja (RA) siempre es 3.
CREATE TABLE IF NOT EXISTS ven_sunat_lote_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_lote                 BIGINT       NOT NULL,
    id_comprobante          BIGINT       NOT NULL,
    estado_item             SMALLINT     NOT NULL DEFAULT 1,
    motivo                  VARCHAR(100),
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_sunat_lote_detalle UNIQUE (id_lote, id_comprobante),
    CONSTRAINT fk_ven_sunat_lote_det_lote FOREIGN KEY (id_lote) REFERENCES ven_sunat_lote (id),
    CONSTRAINT fk_ven_sunat_lote_det_comp FOREIGN KEY (id_comprobante) REFERENCES ven_comprobante (id)
);

-- Bitácora de cada llamada a APIsPERU (sin los archivos en base64).
CREATE TABLE IF NOT EXISTS ven_comprobante_sunat_log (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_comprobante          BIGINT,
    id_lote                 BIGINT,
    operacion               VARCHAR(30)  NOT NULL,
    exito                   BOOLEAN      NOT NULL,
    codigo                  VARCHAR(20),
    mensaje                 TEXT,
    respuesta               JSONB,
    id_usuario              BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ven_comp_sunat_log_comp FOREIGN KEY (id_comprobante) REFERENCES ven_comprobante (id),
    CONSTRAINT fk_ven_comp_sunat_log_lote FOREIGN KEY (id_lote) REFERENCES ven_sunat_lote (id),
    CONSTRAINT fk_ven_comp_sunat_log_usr FOREIGN KEY (id_usuario) REFERENCES auth_usuario (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_ven_comp_sunat_pendiente ON ven_comprobante (estado_sunat, fecha_limite_envio)
  WHERE estado = 1 AND tipo_comprobante IN (1, 2);
CREATE INDEX IF NOT EXISTS ix_ven_sunat_lote_det_comp ON ven_sunat_lote_detalle (id_comprobante);
CREATE INDEX IF NOT EXISTS ix_ven_comp_sunat_log_comp ON ven_comprobante_sunat_log (id_comprobante, id DESC);

-- Listas.
INSERT INTO gen_lista (codigo, nombre, descripcion) VALUES
    ('SUNAT_AMBIENTE', 'Ambiente SUNAT', 'Beta (pruebas) o producción'),
    ('SUNAT_FORMA_ENVIO', 'Forma de envío SUNAT', 'Individual o resumen diario')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO gen_lista_opcion (id_lista, codigo, nombre, valor_entero, orden)
SELECT l.id, v.codigo, v.nombre, v.valor, v.orden
FROM (VALUES
    ('SUNAT_ESTADO', 'NO_APLICA', 'No se envía', 0, 0),
    ('SUNAT_ESTADO', 'EN_PROCESO', 'En proceso', 5, 5),
    ('SUNAT_AMBIENTE', 'BETA', 'Beta (pruebas)', 1, 1),
    ('SUNAT_AMBIENTE', 'PRODUCCION', 'Producción', 2, 2),
    ('SUNAT_FORMA_ENVIO', 'INDIVIDUAL', 'Individual', 1, 1),
    ('SUNAT_FORMA_ENVIO', 'RESUMEN', 'Resumen diario', 2, 2)
) AS v(lista, codigo, nombre, valor, orden)
JOIN gen_lista l ON l.codigo = v.lista
ON CONFLICT (id_lista, codigo) DO NOTHING;

-- Las notas de venta nunca van a SUNAT.
UPDATE ven_comprobante SET estado_sunat = 0 WHERE tipo_comprobante NOT IN (1, 2) AND estado_sunat = 1;

-- Detalle de comprobantes ya emitidos: se completa con la regla de afecto_igv del pedido.
UPDATE ven_comprobante_detalle cd SET
    id_producto = d.id_producto,
    unidad_sunat = COALESCE(NULLIF(btrim(u.codigo_sunat), ''), 'NIU'),
    tipo_afectacion_igv = CASE WHEN p.tasa_igv = 0 THEN '20' ELSE '10' END,
    tasa_igv = p.tasa_igv,
    monto_base_igv = x.base,
    monto_igv = x.total - x.base,
    valor_unitario = round(x.base / NULLIF(cd.cantidad, 0), 10),
    precio_unitario_igv = round(x.total / NULLIF(cd.cantidad, 0), 10)
FROM ven_pedido_detalle d
JOIN ven_pedido p ON p.id = d.id_pedido
JOIN pro_producto pr ON pr.id = d.id_producto
JOIN pro_unidad_medida u ON u.id = pr.id_unidad_medida
CROSS JOIN LATERAL (SELECT
    CASE WHEN d.afecto_igv THEN round(d.monto_subtotal / (1 + p.tasa_igv / 100), 2) ELSE d.monto_subtotal END AS base,
    CASE WHEN d.afecto_igv THEN d.monto_subtotal ELSE round(d.monto_subtotal * (1 + p.tasa_igv / 100), 2) END AS total) x
WHERE cd.id_pedido_detalle = d.id AND cd.monto_base_igv IS NULL;

COMMIT;

-- Funciones SUNAT, empresa y las existentes que cambiaron, más los permisos.
\ir ../instalar_sunat.sql
