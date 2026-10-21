-- Reactivo una persona dada de baja, siempre que su convenio siga activo.
DROP FUNCTION IF EXISTS cli_activar_persona(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION cli_activar_persona(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_convenio BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_convenio INTO v_id_convenio
    FROM cli_persona
    WHERE id = p_id AND estado = 0;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    IF v_id_convenio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_convenio WHERE id = v_id_convenio AND estado = 1
    ) THEN
        RETURN json_build_object(
            'activado', FALSE,
            'id', p_id,
            'error', 'No se puede reactivar: el convenio asignado está inactivo. ' ||
                     'Reactiva el convenio o asígnale otro a la persona.'
        );
    END IF;

    UPDATE cli_persona
    SET estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 0;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;
