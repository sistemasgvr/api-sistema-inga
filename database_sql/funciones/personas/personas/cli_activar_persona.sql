-- Reactivo una persona dada de baja, siempre que su convenio siga activo.
DROP FUNCTION IF EXISTS cli_activar_persona(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION cli_activar_persona(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_convenio BIGINT;
    v_empresa BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_empresa := COALESCE(p_id_empresa, (SELECT id_empresa FROM cli_persona WHERE id = p_id));

    SELECT id_convenio INTO v_id_convenio
    FROM cli_persona
    WHERE id = p_id AND estado = 0
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    IF v_id_convenio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_convenio WHERE id = v_id_convenio AND estado = 1
          AND (v_empresa IS NULL OR id_empresa = v_empresa)
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
    WHERE id = p_id AND estado = 0
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;