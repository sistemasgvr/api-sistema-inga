-- Sucursales activas en las que puede trabajar el usuario; la predeterminada primero.
DROP FUNCTION IF EXISTS auth_sucursales_usuario(p_id_usuario BIGINT);
CREATE OR REPLACE FUNCTION auth_sucursales_usuario(p_id_usuario BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SELECT COALESCE(json_agg(json_build_object(
        'id', s.id,
        'codigo', s.codigo,
        'nombre', s.nombre,
        'es_predeterminada', us.es_predeterminada
    ) ORDER BY us.es_predeterminada DESC, s.nombre), '[]'::JSON)
    INTO v_registros
    FROM auth_usuario_sucursal us
    INNER JOIN gen_sucursal s ON s.id = us.id_sucursal
    WHERE us.id_usuario = p_id_usuario
      AND us.estado = 1
      AND s.estado = 1;

    RETURN v_registros;
END;
$function$;
