-- El código no se edita: es el identificador interno del rol (p. ej. 'ADMIN')
-- y cambiarlo rompería los permisos que dependen de él.
CREATE OR REPLACE FUNCTION auth_actualizar_rol(
    p_id BIGINT,
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_rol
        WHERE LOWER(nombre) = LOWER(v_nombre) AND id <> p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro rol con el nombre ' || v_nombre, 'registro', NULL);
    END IF;

    UPDATE auth_rol
    SET
        nombre = COALESCE(v_nombre, nombre),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Rol no encontrado o inactivo', 'registro', NULL);
    END IF;

    RETURN auth_obtener_rol(p_id);
END;
$function$;
