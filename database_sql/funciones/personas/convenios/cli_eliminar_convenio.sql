-- Doy de baja lógica un convenio (estado = 0). Nunca borro la fila.
--
-- No puedo borrar de verdad porque cxc_movimiento guarda el historial de
-- consumos a crédito y perdería la trazabilidad de las quincenas ya cerradas.
--
-- Bloqueo la baja si todavía hay clientes colgando del convenio, igual que
-- gen_eliminar_almacen bloquea cuando hay stock. Si dejara pasar la baja,
-- esos clientes quedarían apuntando a un convenio muerto y el cobro a crédito
-- (M12) fallaría recién al momento de cobrar, con el cliente en la caja.
CREATE OR REPLACE FUNCTION cli_eliminar_convenio(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_personas INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_personas
    FROM cli_persona
    WHERE id_convenio = p_id AND estado = 1;

    IF v_personas > 0 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede dar de baja el convenio porque tiene ' || v_personas ||
                     ' cliente(s) asignado(s). Reasígnalos a otro convenio primero.'
        );
    END IF;

    UPDATE cli_convenio
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
