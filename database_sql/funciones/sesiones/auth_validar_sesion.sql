CREATE OR REPLACE FUNCTION auth_validar_sesion(p_refresh_token_hash VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_valida BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT
        TRUE,
        json_build_object(
            'id', s.id,
            'id_usuario', u.id,
            'nombre_usuario', u.username,
            'correo', u.email,
            'nombres', u.nombres,
            'apellidos', u.apellidos,
            'es_super_admin', u.es_super_admin,
            'estado', u.estado,
            'fecha_inicio', s.fecha_inicio
        )
    INTO v_valida, v_registro
    FROM auth_sesion s
    INNER JOIN auth_usuario u ON s.id_usuario = u.id
    WHERE s.refresh_token_hash = p_refresh_token_hash
      AND s.estado = 1
      AND s.fecha_expiracion > NOW()
      AND u.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('valida', FALSE, 'registro', NULL);
    END IF;

    RETURN json_build_object('valida', TRUE, 'registro', v_registro);
END;
$function$;