-- Anulo un movimiento de CxC (borrado lógico: estado = 0).
--
-- No borro físicamente nada. El movimiento sigue en la tabla, solo deja de
-- contar para el saldo, porque cxc_calcular_saldo_persona filtra estado = 1.
--
-- Dos reglas que pongo a propósito:
--   1. No se anula un movimiento que vino de un pedido (id_pedido NOT NULL).
--      Ese consumo nació de una venta; si la venta se anula, M12 tendrá que
--      revertirla por su lado. Anularlo suelto dejaría la caja y la cuenta
--      contando cosas distintas.
--   2. No se anula un movimiento de una quincena ya cerrada, entendiendo por
--      cerrada cualquiera anterior a la quincena en curso. Si el corte ya se le
--      envió a la empresa, cambiarle el pasado le rompe la conciliación: para
--      eso está el ajuste.
CREATE OR REPLACE FUNCTION cxc_anular_movimiento(
    p_id BIGINT,
    p_motivo VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov RECORD;
    v_anio_actual SMALLINT;
    v_mes_actual SMALLINT;
    v_quincena_actual SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_mov FROM cxc_movimiento WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El movimiento no existe', 'registro', NULL);
    END IF;

    IF v_mov.estado = 0 THEN
        RETURN json_build_object('error', 'El movimiento ya estaba anulado', 'registro', NULL);
    END IF;

    IF v_mov.id_pedido IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'Este consumo viene de un pedido. Anula el pedido para revertirlo, o registra un ajuste.',
            'registro', NULL
        );
    END IF;

    v_anio_actual := EXTRACT(YEAR FROM CURRENT_DATE)::SMALLINT;
    v_mes_actual := EXTRACT(MONTH FROM CURRENT_DATE)::SMALLINT;
    v_quincena_actual := CASE WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 15 THEN 1 ELSE 2 END;

    IF (v_mov.anio, v_mov.mes, v_mov.quincena) < (v_anio_actual, v_mes_actual, v_quincena_actual) THEN
        RETURN json_build_object(
            'error', 'La quincena ' || v_mov.quincena || '/' || v_mov.mes || '/' || v_mov.anio ||
                     ' ya está cerrada. Corrige con un ajuste para no romper el corte enviado.',
            'registro', NULL
        );
    END IF;

    UPDATE cxc_movimiento
    SET estado = 0,
        observacion = COALESCE(observacion || ' | ', '') || 'ANULADO: ' ||
                      COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado'),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN cxc_obtener_movimiento(p_id);
END;
$function$;
