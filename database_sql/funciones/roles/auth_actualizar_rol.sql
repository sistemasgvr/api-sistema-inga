CREATE OR REPLACE FUNCTION auth_actualizar_rol(
    p_id BIGINT,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF p_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_rol
        WHERE LOWER(codigo) = LOWER(p_codigo) AND id <> p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El código de rol ya está en uso', 'registro', NULL);
    END IF;

    UPDATE auth_rol
    SET
        codigo = COALESCE(UPPER(p_codigo), codigo),
        nombre = COALESCE(p_nombre, nombre),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Rol no encontrado o inactivo', 'registro', NULL);
    END IF;

    RETURN auth_obtener_rol(p_id);
END;
$function$;