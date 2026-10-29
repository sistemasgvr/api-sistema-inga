-- Abre la sesión en la sucursal indicada o, si no se indica, en la predeterminada del
-- usuario (la primera de sus sucursales si no tiene predeterminada).
DROP FUNCTION IF EXISTS auth_crear_sesion(
    p_id_usuario BIGINT,
    p_refresh_token_hash VARCHAR,
    p_ip VARCHAR,
    p_user_agent VARCHAR,
    p_fecha_expiracion TIMESTAMPTZ
);
DROP FUNCTION IF EXISTS auth_crear_sesion(
    p_id_usuario BIGINT,
    p_refresh_token_hash VARCHAR,
    p_ip VARCHAR,
    p_user_agent VARCHAR,
    p_fecha_expiracion TIMESTAMPTZ,
    p_id_sucursal_activa BIGINT
);
CREATE OR REPLACE FUNCTION auth_crear_sesion(
    p_id_usuario BIGINT,
    p_refresh_token_hash VARCHAR,
    p_ip VARCHAR DEFAULT NULL,
    p_user_agent VARCHAR DEFAULT NULL,
    p_fecha_expiracion TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
    p_id_sucursal_activa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_sucursal BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT us.id_sucursal
    INTO v_sucursal
    FROM auth_usuario_sucursal us
    INNER JOIN gen_sucursal s ON s.id = us.id_sucursal AND s.estado = 1
    WHERE us.id_usuario = p_id_usuario
      AND us.estado = 1
      AND (p_id_sucursal_activa IS NULL OR us.id_sucursal = p_id_sucursal_activa)
    ORDER BY us.es_predeterminada DESC, us.id
    LIMIT 1;

    INSERT INTO auth_sesion (
        id_usuario,
        refresh_token_hash,
        ip,
        user_agent,
        fecha_inicio,
        fecha_expiracion,
        id_sucursal_activa,
        estado
    )
    VALUES (
        p_id_usuario,
        p_refresh_token_hash,
        p_ip,
        p_user_agent,
        NOW(),
        p_fecha_expiracion,
        v_sucursal,
        1
    )
    RETURNING id INTO v_id;

    RETURN json_build_object('id_sesion', v_id, 'id_sucursal_activa', v_sucursal);
END;
$function$;
