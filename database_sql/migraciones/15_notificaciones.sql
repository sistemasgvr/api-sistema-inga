-- Tablas de notificaciones (historial + estado de lectura por usuario).
CREATE TABLE IF NOT EXISTS notificaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canal VARCHAR(40) NOT NULL,
  titulo VARCHAR(120) NOT NULL,
  mensaje TEXT NOT NULL,
  severidad VARCHAR(10) NOT NULL DEFAULT 'info',
  ruta VARCHAR(255) NOT NULL,
  id_referencia BIGINT NULL,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notificacion_lectura (
  id_notificacion UUID NOT NULL REFERENCES notificaciones(id) ON DELETE CASCADE,
  id_usuario BIGINT NOT NULL,
  leida_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id_notificacion, id_usuario)
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_canal_creada ON notificaciones (canal, creada_en DESC);
CREATE INDEX IF NOT EXISTS idx_notificacion_lectura_usuario ON notificacion_lectura (id_usuario);
