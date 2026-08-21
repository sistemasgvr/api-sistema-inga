CREATE OR REPLACE FUNCTION auth_crear_rol(
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF EXISTS (SELECT 1 FROM auth_rol WHERE LOWER(codigo) = LOWER(p_codigo) AND estado = 1) THEN
        RETURN json_build_object('error', 'El código de rol ya existe', 'registro', NULL);
    END IF;

    INSERT INTO auth_rol (
        codigo,
        nombre,
        descripcion,
        estado,
        id_usuario_creacion
    )
    VALUES (
        UPPER(p_codigo),
        p_nombre,
        p_descripcion,
        1,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN auth_obtener_rol(v_id);
END;
$function$;