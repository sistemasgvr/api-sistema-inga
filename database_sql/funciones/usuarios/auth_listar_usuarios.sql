CREATE OR REPLACE FUNCTION auth_listar_usuarios(
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
    v_cant_total BIGINT;
    v_cant_activos BIGINT;
    v_cant_inactivos BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE u.estado = 1),
        COUNT(*) FILTER (WHERE u.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM auth_usuario u
    WHERE (
        p_busqueda = ''
        OR LOWER(u.username) LIKE LOWER('%' || p_busqueda || '%')
        OR LOWER(u.email) LIKE LOWER('%' || p_busqueda || '%')
        OR LOWER(u.nombres) LIKE LOWER('%' || p_busqueda || '%')
        OR LOWER(u.apellidos) LIKE LOWER('%' || p_busqueda || '%')
    );

    SELECT COUNT(*) INTO v_total
    FROM auth_usuario u
    WHERE (p_estado IS NULL OR u.estado = p_estado)
      AND (
          p_busqueda = ''
          OR LOWER(u.username) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(u.email) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(u.nombres) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(u.apellidos) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            u.id,
            u.username,
            u.email,
            u.nombres,
            u.apellidos,
            u.telefono,
            u.id_sucursal_default,
            u.es_super_admin, 
            u.estado,
            u.fecha_creacion,
            u.fecha_modificacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', r.id,
                    'codigo', r.codigo,
                    'nombre', r.nombre
                )), '[]'::JSON)
                FROM auth_usuario_rol ur
                INNER JOIN auth_rol r ON ur.id_rol = r.id
                WHERE ur.id_usuario = u.id AND ur.estado = 1 AND r.estado = 1
            ) AS roles
        FROM auth_usuario u
        WHERE (p_estado IS NULL OR u.estado = p_estado)
          AND (
              p_busqueda = ''
              OR LOWER(u.username) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(u.email) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(u.nombres) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(u.apellidos) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY u.nombres ASC, u.apellidos ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total', v_cant_total,
            'activos', v_cant_activos,
            'inactivos', v_cant_inactivos
        )
    );
END;
$function$;