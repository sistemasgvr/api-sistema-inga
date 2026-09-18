-- Devuelve el saldo actual que una persona le debe al restaurante.
--
-- Espejo exacto de cxp_calcular_saldo_proveedor, pero al revés: allá nosotros
-- debemos, acá nos deben.
--
-- La saqué a una función propia porque cuatro sitios la necesitan: registrar un
-- consumo, registrar un abono, el estado de cuenta y la validación de que el
-- abono no supere la deuda. Si el cálculo estuviera copiado, alcanzaría con que
-- alguien corrija uno para que los saldos empiecen a mentir.
--
-- Convención de signos (la misma que ya usa vw_cxc_saldo_persona):
--   tipo 1 = cargo  → consumió a crédito, AUMENTA lo que nos debe
--   tipo 2 = abono  → pagó o se le descontó de planilla, REDUCE
--   tipo 3 = ajuste → corrección manual, ya viene con su signo aplicado
--
-- Resultado positivo = nos debe. Cero = está al día.
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
