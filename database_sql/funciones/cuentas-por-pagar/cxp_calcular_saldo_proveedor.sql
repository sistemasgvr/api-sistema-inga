-- Devuelve el saldo actual que le debemos a un proveedor.
--
-- La saqué a una función propia porque cuatro sitios la necesitan: registrar
-- un cargo, registrar un abono, el detalle del proveedor y la validación de
-- que el abono no supere la deuda. Si el cálculo estuviera copiado, alcanzaría
-- con que alguien corrija uno para que los saldos empiecen a mentir.
--
-- Convención de signos (espejo de CxC, pero al revés):
--   tipo 1 = cargo  → compramos a crédito, AUMENTA lo que debemos
--   tipo 2 = abono  → le pagamos, REDUCE
--   tipo 3 = ajuste → corrección manual, ya viene con su signo en el monto
--
-- Resultado positivo = le debemos. Cero = estamos al día.
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
