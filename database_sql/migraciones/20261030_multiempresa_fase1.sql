-- Multiempresa, fase 1: empresa del trabajador, sucursales por usuario y sucursal
-- activa de la sesión. Re-ejecutable.
--
-- Reglas: un usuario pertenece a una sola empresa (la de su trabajador) y puede
-- trabajar en varias sucursales de esa empresa; la sesión guarda en cuál trabaja.
BEGIN;

-- Empresa del trabajador.
ALTER TABLE pla_trabajador ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
DO $mig$ BEGIN
    ALTER TABLE pla_trabajador ADD CONSTRAINT fk_pla_trabajador_empresa FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- Datos existentes: la empresa de su sucursal o, si no tiene, la única empresa activa.
UPDATE pla_trabajador t
SET id_empresa = s.id_empresa
FROM gen_sucursal s
WHERE s.id = t.id_sucursal
  AND t.id_empresa IS NULL;

UPDATE pla_trabajador
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;

-- Obligatoria en cuanto todos los trabajadores la tienen (si no, lo exigen las funciones).
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pla_trabajador WHERE id_empresa IS NULL) THEN
        ALTER TABLE pla_trabajador ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

CREATE INDEX IF NOT EXISTS ix_pla_trabajador_empresa ON pla_trabajador (id_empresa);

-- Sucursales en las que puede trabajar cada usuario (todas de su empresa).
CREATE TABLE IF NOT EXISTS auth_usuario_sucursal (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario              BIGINT       NOT NULL,
    id_sucursal             BIGINT       NOT NULL,
    es_predeterminada       BOOLEAN      NOT NULL DEFAULT FALSE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_auth_usuario_sucursal UNIQUE (id_usuario, id_sucursal),
    CONSTRAINT fk_auth_usuario_sucursal_usuario FOREIGN KEY (id_usuario) REFERENCES auth_usuario (id),
    CONSTRAINT fk_auth_usuario_sucursal_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id),
    CONSTRAINT fk_auth_usuario_sucursal_usr_creacion FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuario (id) ON DELETE SET NULL,
    CONSTRAINT fk_auth_usuario_sucursal_usr_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuario (id) ON DELETE SET NULL
);

-- Una sola sucursal predeterminada vigente por usuario.
CREATE UNIQUE INDEX IF NOT EXISTS uq_auth_usuario_sucursal_predeterminada
    ON auth_usuario_sucursal (id_usuario)
    WHERE es_predeterminada AND estado = 1;

-- Sucursal en la que trabaja cada sesión.
ALTER TABLE auth_sesion ADD COLUMN IF NOT EXISTS id_sucursal_activa BIGINT;
DO $mig$ BEGIN
    ALTER TABLE auth_sesion ADD CONSTRAINT fk_auth_sesion_sucursal FOREIGN KEY (id_sucursal_activa) REFERENCES gen_sucursal (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- La vista del usuario expone su empresa (al final: CREATE OR REPLACE VIEW solo agrega columnas).
CREATE OR REPLACE VIEW auth_usuario_datos AS
SELECT u.id, u.username, u.password_hash, u.pin_hash, u.es_super_admin,
       u.estado, u.fecha_creacion, u.fecha_modificacion, u.id_trabajador,
       t.nombres, t.apellidos, t.email, t.telefono,
       t.id_sucursal AS id_sucursal_default, t.estado AS estado_trabajador,
       t.id_empresa
FROM auth_usuario u
JOIN pla_trabajador t ON t.id = u.id_trabajador;

-- Usuarios existentes: la sucursal de su trabajador queda como predeterminada.
INSERT INTO auth_usuario_sucursal (id_usuario, id_sucursal, es_predeterminada)
SELECT u.id, t.id_sucursal, TRUE
FROM auth_usuario u
INNER JOIN pla_trabajador t ON t.id = u.id_trabajador
INNER JOIN gen_sucursal s ON s.id = t.id_sucursal
WHERE NOT EXISTS (
    SELECT 1 FROM auth_usuario_sucursal us
    WHERE us.id_usuario = u.id AND us.estado = 1
)
ON CONFLICT ON CONSTRAINT uq_auth_usuario_sucursal DO NOTHING;

COMMIT;

\ir ../funciones/usuarios/auth_validar_empresa_sucursal.sql
\ir ../funciones/usuarios/auth_sucursales_usuario.sql
\ir ../funciones/usuarios/auth_asignar_sucursales_usuario.sql
\ir ../funciones/login/auth_obtener_usuario_por_login.sql
\ir ../funciones/sesiones/auth_crear_sesion.sql
\ir ../funciones/sesiones/auth_validar_sesion.sql
\ir ../funciones/sesiones/auth_cambiar_sucursal_sesion.sql
\ir ../funciones/usuarios/auth_obtener_usuario.sql
\ir ../funciones/usuarios/auth_listar_usuarios.sql
\ir ../funciones/usuarios/auth_crear_usuario.sql
\ir ../funciones/usuarios/auth_actualizar_usuario.sql
\ir ../funciones/usuarios/auth_listar_trabajadores_disponibles.sql
\ir ../funciones/planilla/trabajadores/pla_obtener_trabajador.sql
\ir ../funciones/planilla/trabajadores/pla_listar_trabajadores.sql
\ir ../funciones/planilla/trabajadores/pla_crear_trabajador.sql
\ir ../funciones/planilla/trabajadores/pla_actualizar_trabajador.sql
\ir ../funciones/general/sucursales/gen_listar_sucursales.sql
