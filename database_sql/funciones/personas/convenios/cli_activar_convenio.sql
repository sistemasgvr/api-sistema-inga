-- Reactivo un convenio que estaba dado de baja.
--
-- El WHERE pide estado = 0 a propósito: si el convenio ya estaba activo,
-- NOT FOUND se dispara y devuelvo activado = FALSE. Prefiero decir "no hice
-- nada" antes que responder un éxito que no ocurrió.
CREATE OR REPLACE FUNCTION cli_activar_convenio(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE cli_convenio
    SET estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 0;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;
