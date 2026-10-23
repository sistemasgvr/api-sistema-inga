-- Notificaciones: destinatarios, outbox para avisos generados en SQL, idempotencia
-- de recordatorios y estado de las alertas de stock mínimo por producto.

ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS ids_usuario_destino BIGINT[];
ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS emitida_en TIMESTAMPTZ;
ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS clave_unica VARCHAR(160);
ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS datos JSONB;

-- Las notificaciones anteriores a esta migración ya se enviaron por socket.
UPDATE notificaciones SET emitida_en = creada_en WHERE emitida_en IS NULL;

-- Outbox: el despachador del backend toma las que aún no se enviaron.
CREATE INDEX IF NOT EXISTS idx_notificaciones_pendientes
    ON notificaciones (creada_en) WHERE emitida_en IS NULL;
-- Un recordatorio periódico no se repite con la misma clave.
CREATE UNIQUE INDEX IF NOT EXISTS uq_notificaciones_clave
    ON notificaciones (clave_unica) WHERE clave_unica IS NOT NULL;
-- Depuración del historial por antigüedad.
CREATE INDEX IF NOT EXISTS idx_notificaciones_creada ON notificaciones (creada_en);

-- Último nivel avisado del stock consolidado de cada producto:
-- 0 normal, 1 bajo el mínimo, 2 agotado. Solo se avisa cuando el nivel empeora.
CREATE TABLE IF NOT EXISTS alm_alerta_stock_estado (
    id_producto             BIGINT       PRIMARY KEY REFERENCES pro_producto (id) ON DELETE CASCADE,
    nivel                   SMALLINT     NOT NULL DEFAULT 0,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_alm_alerta_stock_nivel CHECK (nivel IN (0, 1, 2))
);

-- Se parte del nivel actual para no avisar de golpe todo lo que ya está bajo el mínimo.
INSERT INTO alm_alerta_stock_estado (id_producto, nivel)
SELECT s.id_producto,
       CASE WHEN SUM(s.stock_minimo) <= 0 THEN 0
            WHEN SUM(s.stock_actual) <= 0 THEN 2
            WHEN SUM(s.stock_actual) <= SUM(s.stock_minimo) THEN 1
            ELSE 0 END
FROM alm_producto_stock s
WHERE s.estado = 1
GROUP BY s.id_producto
ON CONFLICT (id_producto) DO NOTHING;
