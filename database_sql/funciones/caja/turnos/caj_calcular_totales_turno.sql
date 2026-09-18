-- Calcula cuánto dinero debería haber en el cajón de un turno.
--
-- La saqué a una función propia porque tres sitios necesitan exactamente el
-- mismo cálculo: el panel del turno activo, el resumen de cierre y la función
-- que cierra el turno y guarda la diferencia. Si lo dejara copiado, alcanzaría
-- con que alguien corrija uno para que el arqueo empiece a mentir.
--
-- LO IMPORTANTE: al cajón solo entra EFECTIVO.
--
--   esperado = monto_apertura
--            + ventas cobradas en efectivo (medio_pago = 1)
--            + ingresos de caja  (tipo_movimiento = 1)
--            - egresos de caja   (tipo_movimiento = 2)
--
-- Yape, tarjeta y crédito (medios 2, 3 y 4) se cobran igual y se muestran en el
-- resumen, pero NO suman al efectivo esperado: ese dinero nunca pasó por el
-- cajón. Sumarlos sería el error clásico que hace que todo cierre con faltante.
CREATE OR REPLACE FUNCTION caj_calcular_totales_turno(p_id_turno BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_apertura NUMERIC(12,2);
    v_efectivo NUMERIC(12,2);
    v_yape NUMERIC(12,2);
    v_tarjeta NUMERIC(12,2);
    v_credito NUMERIC(12,2);
    v_ingresos NUMERIC(12,2);
    v_egresos NUMERIC(12,2);
BEGIN
    SELECT COALESCE(monto_apertura, 0) INTO v_apertura
    FROM caj_turno WHERE id = p_id_turno;

    IF v_apertura IS NULL THEN
        v_apertura := 0;
    END IF;

    -- Ventas del turno separadas por medio de pago.
    -- Catálogo MEDIO_PAGO: 1 efectivo, 2 yape, 3 tarjeta, 4 crédito.
    SELECT
        COALESCE(SUM(monto) FILTER (WHERE medio_pago = 1), 0),
        COALESCE(SUM(monto) FILTER (WHERE medio_pago = 2), 0),
        COALESCE(SUM(monto) FILTER (WHERE medio_pago = 3), 0),
        COALESCE(SUM(monto) FILTER (WHERE medio_pago = 4), 0)
    INTO v_efectivo, v_yape, v_tarjeta, v_credito
    FROM ven_pago
    WHERE id_turno = p_id_turno AND estado = 1;

    -- Movimientos manuales de caja (CAJA_MOV_TIPO: 1 ingreso, 2 egreso).
    SELECT
        COALESCE(SUM(monto) FILTER (WHERE tipo_movimiento = 1), 0),
        COALESCE(SUM(monto) FILTER (WHERE tipo_movimiento = 2), 0)
    INTO v_ingresos, v_egresos
    FROM caj_movimiento
    WHERE id_turno = p_id_turno AND estado = 1;

    RETURN json_build_object(
        'monto_apertura', v_apertura,
        'ventas_efectivo', v_efectivo,
        'ventas_yape', v_yape,
        'ventas_tarjeta', v_tarjeta,
        'ventas_credito', v_credito,
        'total_ventas', v_efectivo + v_yape + v_tarjeta + v_credito,
        'ingresos_caja', v_ingresos,
        'egresos_caja', v_egresos,
        -- Este es el número contra el que se compara el conteo físico.
        'efectivo_esperado', v_apertura + v_efectivo + v_ingresos - v_egresos
    );
END;
$function$;
