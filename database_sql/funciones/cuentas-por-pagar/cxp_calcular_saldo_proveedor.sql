-- Devuelve el saldo actual que le debemos a un proveedor (positivo = le debemos).
-- Tipo 1 cargo suma, tipo 2 abono resta, tipo 3 ajuste ya trae su signo.
DROP FUNCTION IF EXISTS cxp_calcular_saldo_proveedor(p_id_persona BIGINT);
CREATE OR REPLACE FUNCTION cxp_calcular_saldo_proveedor(p_id_persona BIGINT)
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
    FROM cxp_movimiento m
    WHERE m.id_persona = p_id_persona AND m.estado = 1;

    RETURN v_saldo;
END;
$function$;
