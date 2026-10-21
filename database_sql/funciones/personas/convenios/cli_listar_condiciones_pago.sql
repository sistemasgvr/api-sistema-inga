-- Listo las condiciones de pago activas (lista corta, sin paginar).
DROP FUNCTION IF EXISTS cli_listar_condiciones_pago();
CREATE OR REPLACE FUNCTION cli_listar_condiciones_pago()
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cp.id,
            cp.codigo,
            cp.nombre,
            cp.dias_credito
        FROM gen_condicion_pago cp
        WHERE cp.estado = 1
        ORDER BY cp.dias_credito ASC, cp.nombre ASC
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
