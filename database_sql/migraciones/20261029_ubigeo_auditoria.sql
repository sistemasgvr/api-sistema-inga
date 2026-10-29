-- Auditoría en las tablas de ubigeo (país, departamento, provincia y distrito),
-- igual que el resto de tablas. Re-ejecutable.
BEGIN;

ALTER TABLE gen_pais
    ADD COLUMN IF NOT EXISTS id_usuario_creacion     BIGINT,
    ADD COLUMN IF NOT EXISTS id_usuario_modificacion BIGINT,
    ADD COLUMN IF NOT EXISTS fecha_creacion          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS fecha_modificacion      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE gen_departamento
    ADD COLUMN IF NOT EXISTS id_usuario_creacion     BIGINT,
    ADD COLUMN IF NOT EXISTS id_usuario_modificacion BIGINT,
    ADD COLUMN IF NOT EXISTS fecha_creacion          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS fecha_modificacion      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE gen_provincia
    ADD COLUMN IF NOT EXISTS id_usuario_creacion     BIGINT,
    ADD COLUMN IF NOT EXISTS id_usuario_modificacion BIGINT,
    ADD COLUMN IF NOT EXISTS fecha_creacion          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS fecha_modificacion      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE gen_distrito
    ADD COLUMN IF NOT EXISTS id_usuario_creacion     BIGINT,
    ADD COLUMN IF NOT EXISTS id_usuario_modificacion BIGINT,
    ADD COLUMN IF NOT EXISTS fecha_creacion          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS fecha_modificacion      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

DO $mig$ BEGIN
    ALTER TABLE gen_pais ADD CONSTRAINT fk_gen_pais_usr_creacion FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

DO $mig$ BEGIN
    ALTER TABLE gen_pais ADD CONSTRAINT fk_gen_pais_usr_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

DO $mig$ BEGIN
    ALTER TABLE gen_departamento ADD CONSTRAINT fk_gen_departamento_usr_creacion FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

DO $mig$ BEGIN
    ALTER TABLE gen_departamento ADD CONSTRAINT fk_gen_departamento_usr_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

DO $mig$ BEGIN
    ALTER TABLE gen_provincia ADD CONSTRAINT fk_gen_provincia_usr_creacion FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

DO $mig$ BEGIN
    ALTER TABLE gen_provincia ADD CONSTRAINT fk_gen_provincia_usr_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

DO $mig$ BEGIN
    ALTER TABLE gen_distrito ADD CONSTRAINT fk_gen_distrito_usr_creacion FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

DO $mig$ BEGIN
    ALTER TABLE gen_distrito ADD CONSTRAINT fk_gen_distrito_usr_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuario (id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

COMMIT;
