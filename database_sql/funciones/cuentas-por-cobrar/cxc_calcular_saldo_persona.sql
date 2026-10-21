-- Devuelve el saldo actual que una persona le debe al restaurante.
DROP FUNCTION IF EXISTS cxc_calcular_saldo_persona(p_id_persona BIGINT);
CREATE OR REPLACE FUNCTION cxc_calcular_saldo_persona(p_id_persona BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $function$
DECLARE
    v_saldo NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(
        CASE
            WHEN m.tipo_movimiento = 1 THEN m.monto
            WHEN m.tipo_movimiento = 2 THEN -m.monto
            ELSE m.monto
        END
    ), 0)
    INTO v_saldo
    FROM cxc_movimiento m
    WHERE m.id_persona = p_id_persona AND m.estado = 1;

    RETURN v_saldo;
END;
$function$;
