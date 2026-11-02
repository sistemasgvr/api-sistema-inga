DROP FUNCTION IF EXISTS auth_activar_rol(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT
);
DROP FUNCTION IF EXISTS auth_activar_rol(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION auth_activar_rol(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    UPDATE auth_rol
    SET estado = 1, id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 0
      AND (p_id_empresa IS NULL OR id_empresa IS NULL OR id_empresa = p_id_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;