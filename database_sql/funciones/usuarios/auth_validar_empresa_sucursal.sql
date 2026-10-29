-- Un usuario pertenece a la empresa de su trabajador: sus sucursales y la sucursal
-- del trabajador deben ser de esa misma empresa. Lo validan estos triggers.

DROP FUNCTION IF EXISTS auth_trg_validar_sucursal_usuario() CASCADE;
CREATE OR REPLACE FUNCTION auth_trg_validar_sucursal_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_empresa_usuario BIGINT;
    v_empresa_sucursal BIGINT;
BEGIN
    IF NEW.estado <> 1 THEN
        RETURN NEW;
    END IF;

    SELECT t.id_empresa
    INTO v_empresa_usuario
    FROM auth_usuario u
    INNER JOIN pla_trabajador t ON t.id = u.id_trabajador
    WHERE u.id = NEW.id_usuario;

    SELECT s.id_empresa
    INTO v_empresa_sucursal
    FROM gen_sucursal s
    WHERE s.id = NEW.id_sucursal;

    IF v_empresa_usuario IS NULL THEN
        RAISE EXCEPTION 'Asigne primero la empresa al trabajador del usuario';
    END IF;

    IF v_empresa_sucursal IS DISTINCT FROM v_empresa_usuario THEN
        RAISE EXCEPTION 'La sucursal pertenece a otra empresa: el usuario solo puede trabajar en sucursales de su empresa';
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_auth_usuario_sucursal_empresa ON auth_usuario_sucursal;
CREATE TRIGGER trg_auth_usuario_sucursal_empresa
BEFORE INSERT OR UPDATE OF id_sucursal, id_usuario, estado ON auth_usuario_sucursal
FOR EACH ROW
EXECUTE PROCEDURE auth_trg_validar_sucursal_usuario();

DROP FUNCTION IF EXISTS pla_trg_validar_empresa_trabajador() CASCADE;
CREATE OR REPLACE FUNCTION pla_trg_validar_empresa_trabajador()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.id_sucursal IS NOT NULL AND NEW.id_empresa IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal s
        WHERE s.id = NEW.id_sucursal
          AND s.id_empresa = NEW.id_empresa
    ) THEN
        RAISE EXCEPTION 'La sucursal del trabajador pertenece a otra empresa';
    END IF;

    -- Cambiar de empresa dejaría al usuario con sucursales ajenas.
    IF TG_OP = 'UPDATE'
       AND NEW.id_empresa IS DISTINCT FROM OLD.id_empresa
       AND OLD.id_empresa IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM auth_usuario u
           INNER JOIN auth_usuario_sucursal us ON us.id_usuario = u.id AND us.estado = 1
           WHERE u.id_trabajador = NEW.id
       ) THEN
        RAISE EXCEPTION 'El trabajador tiene un usuario con sucursales asignadas: no puede cambiar de empresa';
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_pla_trabajador_empresa ON pla_trabajador;
CREATE TRIGGER trg_pla_trabajador_empresa
BEFORE INSERT OR UPDATE OF id_sucursal, id_empresa ON pla_trabajador
FOR EACH ROW
EXECUTE PROCEDURE pla_trg_validar_empresa_trabajador();
