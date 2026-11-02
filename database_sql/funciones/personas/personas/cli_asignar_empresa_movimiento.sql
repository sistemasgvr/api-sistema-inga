-- Trigger: los movimientos de CxC y CxP toman la empresa de su cliente o proveedor
-- cuando no la traen. Re-ejecutable: quita y vuelve a crear los triggers.
DROP TRIGGER IF EXISTS trg_cxc_movimiento_empresa ON cxc_movimiento;
DROP TRIGGER IF EXISTS trg_cxp_movimiento_empresa ON cxp_movimiento;
DROP FUNCTION IF EXISTS cli_asignar_empresa_movimiento();
CREATE OR REPLACE FUNCTION cli_asignar_empresa_movimiento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.id_empresa IS NULL THEN
        SELECT p.id_empresa
        INTO NEW.id_empresa
        FROM cli_persona p
        WHERE p.id = NEW.id_persona;
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_cxc_movimiento_empresa
BEFORE INSERT ON cxc_movimiento
FOR EACH ROW
EXECUTE FUNCTION cli_asignar_empresa_movimiento();

CREATE TRIGGER trg_cxp_movimiento_empresa
BEFORE INSERT ON cxp_movimiento
FOR EACH ROW
EXECUTE FUNCTION cli_asignar_empresa_movimiento();
