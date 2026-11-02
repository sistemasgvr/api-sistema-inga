-- Trigger: toda empresa nueva recibe sus catálogos base (cliente genérico y
-- categorías de gasto). Re-ejecutable: el archivo mismo quita y vuelve a crear
-- el trigger.
DROP TRIGGER IF EXISTS trg_gen_empresa_catalogos ON gen_empresa;
DROP FUNCTION IF EXISTS gen_empresa_crear_catalogos();
CREATE OR REPLACE FUNCTION gen_empresa_crear_catalogos()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM gen_crear_catalogos_empresa(NEW.id);
    RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_gen_empresa_catalogos
AFTER INSERT ON gen_empresa
FOR EACH ROW
EXECUTE FUNCTION gen_empresa_crear_catalogos();
