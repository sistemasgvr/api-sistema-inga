-- Trigger: toda empresa nueva recibe sus series B001, F001 y NV01. La numeración
-- es por empresa (RUC), compartida entre sus sucursales. Re-ejecutable: el archivo
-- mismo quita y vuelve a crear el trigger.
DROP TRIGGER IF EXISTS trg_gen_empresa_series ON gen_empresa;
DROP FUNCTION IF EXISTS gen_empresa_crear_series();
CREATE OR REPLACE FUNCTION gen_empresa_crear_series()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM gen_crear_series_empresa(NEW.id);
    RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_gen_empresa_series
AFTER INSERT ON gen_empresa
FOR EACH ROW
EXECUTE FUNCTION gen_empresa_crear_series();
