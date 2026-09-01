CREATE OR REPLACE FUNCTION gen_listar_sucursales(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_estado INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_activos BIGINT;
    v_inactivos BIGINT;
    v_total_global BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE s.estado = 1),
        COUNT(*) FILTER (WHERE s.estado = 0)
    INTO 
        v_total_global,
        v_activos,
        v_inactivos
    FROM gen_sucursal s;

    SELECT COUNT(*) INTO v_total
    FROM gen_sucursal s
    WHERE (p_estado IS NULL OR s.estado = p_estado)
      AND (
          p_busqueda = ''
          OR LOWER(s.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(s.direccion) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.id_empresa,
            s.codigo,
            s.nombre,
            s.direccion,
            s.telefono,
            s.id_distrito,
            s.es_principal,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            (
                SELECT COUNT(*)
                FROM auth_usuario u
                WHERE u.id_sucursal_default = s.id AND u.estado = 1
            ) AS total_usuarios
        FROM gen_sucursal s
        WHERE (p_estado IS NULL OR s.estado = p_estado)
          AND (
              p_busqueda = ''
              OR LOWER(s.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(s.direccion) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY s.es_principal DESC, s.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total', v_total_global,
            'activos', v_activos,
            'inactivos', v_inactivos
        )
    );
END;
$function$;