-- Cambia la sucursal en la que trabaja la sesión. Solo a una sucursal activa asignada
-- al usuario (por lo tanto, de su empresa).
DROP FUNCTION IF EXISTS auth_cambiar_sucursal_sesion(
    p_id_sesion BIGINT,
    p_id_usuario BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION auth_cambiar_sucursal_sesion(
    p_id_sesion BIGINT,
    p_id_usuario BIGINT,
    p_id_sucursal BIGINT
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_sucursal JSON;
BEGIN
    SELECT json_build_object('id', s.id, 'codigo', s.codigo, 'nombre', s.nombre)
    INTO v_sucursal
    FROM auth_usuario_sucursal us
    INNER JOIN gen_sucursal s ON s.id = us.id_sucursal AND s.estado = 1
    WHERE us.id_usuario = p_id_usuario
      AND us.id_sucursal = p_id_sucursal
      AND us.estado = 1;

    IF v_sucursal IS NULL THEN
        RETURN json_build_object('error', 'No tiene acceso a esa sucursal', 'registro', NULL);
    END IF;

    UPDATE auth_sesion
    SET id_sucursal_activa = p_id_sucursal,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = p_id_sesion
      AND id_usuario = p_id_usuario
      AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La sesión no existe o ya se cerró', 'registro', NULL);
    END IF;

    RETURN json_build_object('registro', v_sucursal);
END;
$function$;
