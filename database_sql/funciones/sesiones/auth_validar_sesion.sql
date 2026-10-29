-- Valida el token de la sesión y devuelve el usuario con su empresa y la sucursal en
-- la que trabaja. Si la sucursal activa ya no le corresponde, usa la predeterminada.
DROP FUNCTION IF EXISTS auth_validar_sesion(p_refresh_token_hash VARCHAR);
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
            'fecha_inicio', s.fecha_inicio,
            'id_empresa', u.id_empresa,
            'id_sucursal_activa', COALESCE(
                (
                    SELECT us.id_sucursal
                    FROM auth_usuario_sucursal us
                    INNER JOIN gen_sucursal gs ON gs.id = us.id_sucursal AND gs.estado = 1
                    WHERE us.id_usuario = u.id
                      AND us.id_sucursal = s.id_sucursal_activa
                      AND us.estado = 1
                ),
                (
                    SELECT us.id_sucursal
                    FROM auth_usuario_sucursal us
                    INNER JOIN gen_sucursal gs ON gs.id = us.id_sucursal AND gs.estado = 1
                    WHERE us.id_usuario = u.id
                      AND us.estado = 1
                    ORDER BY us.es_predeterminada DESC, us.id
                    LIMIT 1
                )
            )
        )
    INTO v_valida, v_registro
    FROM auth_sesion s
    INNER JOIN auth_usuario_datos u ON s.id_usuario = u.id
    WHERE s.refresh_token_hash = p_refresh_token_hash
      AND s.estado = 1
      AND s.fecha_expiracion > NOW()
      AND u.estado = 1 AND u.estado_trabajador = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('valida', FALSE, 'registro', NULL);
    END IF;

    RETURN json_build_object('valida', TRUE, 'registro', v_registro);
END;
$function$;
