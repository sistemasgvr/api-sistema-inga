-- Doy de baja lógica un trabajador (estado = 0). Nunca borro la fila.
--
-- No puedo borrar de verdad porque pla_pago apunta a él y perdería el
-- histórico de planilla, que es justo lo que alimenta el cálculo de
-- rentabilidad del dashboard.
--
-- A diferencia de personas o convenios, acá NO bloqueo la baja por tener
-- pagos: que un trabajador ya no esté en el equipo es lo normal, y sus pagos
-- pasados siguen siendo válidos. Lo único que impido es dejar a medias el
-- período en curso, avisando si ya tiene un pago registrado este mes.
CREATE OR REPLACE FUNCTION pla_eliminar_trabajador(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pla_trabajador
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
