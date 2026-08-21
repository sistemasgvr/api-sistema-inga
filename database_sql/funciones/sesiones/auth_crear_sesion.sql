CREATE OR REPLACE FUNCTION auth_crear_sesion(
    p_id_usuario BIGINT,
    p_refresh_token_hash VARCHAR,
    p_ip VARCHAR DEFAULT NULL,
    p_user_agent VARCHAR DEFAULT NULL,
    p_fecha_expiracion TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    INSERT INTO auth_sesion (
        id_usuario,
        refresh_token_hash,
        ip,
        user_agent,
        fecha_inicio,
        fecha_expiracion,
        estado
    )
    VALUES (
        p_id_usuario,
        p_refresh_token_hash,
        p_ip,
        p_user_agent,
        NOW(),
        p_fecha_expiracion,
        1
    )
    RETURNING id INTO v_id;

    RETURN json_build_object('id_sesion', v_id);
END;
$function$;
