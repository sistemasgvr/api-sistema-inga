CREATE OR REPLACE FUNCTION gen_actualizar_sucursal(
    p_id BIGINT,
    p_id_empresa BIGINT DEFAULT NULL,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_id_distrito BIGINT DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_empresa_id BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT id_empresa INTO v_empresa_id FROM gen_sucursal WHERE id = p_id;

    IF p_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_sucursal
        WHERE LOWER(codigo) = LOWER(p_codigo) 
          AND id_empresa = COALESCE(p_id_empresa, v_empresa_id)
          AND id <> p_id 
          AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El código de sucursal ya está en uso', 'registro', NULL);
    END IF;

    IF p_es_principal = TRUE THEN
        UPDATE gen_sucursal 
        SET es_principal = FALSE, id_usuario_modificacion = p_id_usuario_auditoria
        WHERE id_empresa = COALESCE(p_id_empresa, v_empresa_id);
    END IF;

    UPDATE gen_sucursal
    SET
        id_empresa = COALESCE(p_id_empresa, id_empresa),
        codigo = COALESCE(UPPER(p_codigo), codigo),
        nombre = COALESCE(p_nombre, nombre),
        direccion = COALESCE(p_direccion, direccion),
        telefono = COALESCE(p_telefono, telefono),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        es_principal = COALESCE(p_es_principal, es_principal),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Sucursal no encontrada o inactiva', 'registro', NULL);
    END IF;

    RETURN gen_obtener_sucursal(p_id);
END;
$function$;