ALTER TABLE pla_trabajador ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE pla_trabajador ADD COLUMN IF NOT EXISTS telefono VARCHAR(20);
ALTER TABLE auth_usuario ADD COLUMN IF NOT EXISTS id_trabajador BIGINT;

DO $mig$
DECLARE u RECORD; trabajador_id BIGINT;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema() AND table_name = 'auth_usuario' AND column_name = 'email') THEN
        FOR u IN EXECUTE 'SELECT * FROM auth_usuario WHERE id_trabajador IS NULL ORDER BY id' LOOP
            INSERT INTO pla_trabajador (nombres, apellidos, email, telefono, id_sucursal, estado)
            VALUES (u.nombres, u.apellidos, NULLIF(LOWER(TRIM(u.email)), ''), u.telefono,
                    u.id_sucursal_default, u.estado)
            RETURNING id INTO trabajador_id;
            UPDATE auth_usuario SET id_trabajador = trabajador_id WHERE id = u.id;
        END LOOP;
    END IF;
END $mig$;

ALTER TABLE auth_usuario ALTER COLUMN id_trabajador SET NOT NULL;
DO $mig$ BEGIN
    ALTER TABLE auth_usuario ADD CONSTRAINT fk_auth_usuario_trabajador
        FOREIGN KEY (id_trabajador) REFERENCES pla_trabajador(id);
EXCEPTION WHEN duplicate_object THEN NULL; END $mig$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_auth_usuario_trabajador ON auth_usuario(id_trabajador);
CREATE UNIQUE INDEX IF NOT EXISTS uq_pla_trabajador_email ON pla_trabajador(LOWER(email)) WHERE email IS NOT NULL;

-- Sin CASCADE: una dependencia desconocida debe detener la migración completa.
ALTER TABLE auth_usuario DROP COLUMN IF EXISTS nombres;
ALTER TABLE auth_usuario DROP COLUMN IF EXISTS apellidos;
ALTER TABLE auth_usuario DROP COLUMN IF EXISTS email;
ALTER TABLE auth_usuario DROP COLUMN IF EXISTS telefono;
ALTER TABLE auth_usuario DROP COLUMN IF EXISTS id_sucursal_default;

-- Eliminar firmas antiguas evita sobrecargas ambiguas y escritura de datos duplicados.
DROP FUNCTION IF EXISTS auth_crear_usuario(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BIGINT,JSON,BIGINT);
DROP FUNCTION IF EXISTS auth_actualizar_usuario(BIGINT,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,BIGINT,JSON,BIGINT);
DROP FUNCTION IF EXISTS pla_crear_trabajador(VARCHAR,VARCHAR,VARCHAR,VARCHAR,NUMERIC,BIGINT,BIGINT);
DROP FUNCTION IF EXISTS pla_actualizar_trabajador(BIGINT,VARCHAR,VARCHAR,VARCHAR,VARCHAR,NUMERIC,BIGINT,BIGINT);
