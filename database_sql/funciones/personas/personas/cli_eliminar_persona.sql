-- Doy de baja lógica una persona (estado = 0).
--
-- No borro la fila: com_compra y cxc_movimiento apuntan a ella y perdería el
-- historial de compras y de consumos a crédito.
--
-- Bloqueo la baja si la persona tiene deuda pendiente. Si la dejara pasar,
-- desaparecería de los listados con plata por cobrar de por medio, que es
-- justo lo que el reporte de quincena (M14) tiene que mostrar.
CREATE OR REPLACE FUNCTION cli_eliminar_persona(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_saldo NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(
        CASE
            WHEN m.tipo_movimiento = 1 THEN m.monto
            WHEN m.tipo_movimiento = 2 THEN -m.monto
            ELSE m.monto
        END
    ), 0)
    INTO v_saldo
    FROM cxc_movimiento m
    WHERE m.id_persona = p_id AND m.estado = 1;

    IF v_saldo > 0 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede dar de baja: la persona tiene un saldo pendiente de S/ ' ||
                     TO_CHAR(v_saldo, 'FM999999990.00') || '. Registra el abono primero.'
        );
    END IF;

    UPDATE cli_persona
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
