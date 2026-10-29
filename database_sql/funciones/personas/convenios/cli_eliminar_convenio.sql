DROP FUNCTION IF EXISTS cli_eliminar_convenio(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION cli_eliminar_convenio(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_personas INTEGER;
    v_empresa BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_empresa := COALESCE(p_id_empresa, (SELECT id_empresa FROM cli_convenio WHERE id = p_id));

    SELECT COUNT(*) INTO v_personas
    FROM cli_persona
    WHERE id_convenio = p_id AND estado = 1
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

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
    WHERE id = p_id AND estado = 1
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;