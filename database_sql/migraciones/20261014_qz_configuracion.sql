-- Configuración global de firma QZ. Ejecutar antes de desplegar la API.
CREATE TABLE IF NOT EXISTS gen_qz_configuracion (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  certificado text NOT NULL,
  clave_privada text NOT NULL,
  actualizado timestamptz NOT NULL DEFAULT now()
);
-- La clave sólo debe ser accesible por el rol del backend.
REVOKE ALL ON gen_qz_configuracion FROM PUBLIC;
ALTER TABLE gen_qz_configuracion ENABLE ROW LEVEL SECURITY;
