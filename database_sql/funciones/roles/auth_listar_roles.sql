CREATE OR REPLACE FUNCTION public.auth_listar_roles(
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
    v_total_permisos_sistema BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT COUNT(*) INTO v_total_permisos_sistema
    FROM public.auth_permiso
    WHERE estado = 1;

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE r.estado = 1),
        COUNT(*) FILTER (WHERE r.estado = 0)
    INTO 
        v_total_global,
        v_activos,
        v_inactivos
    FROM public.auth_rol r;

    SELECT COUNT(*) INTO v_total
    FROM public.auth_rol r
    WHERE (p_estado IS NULL OR r.estado = p_estado)
      AND (
          p_busqueda = ''
          OR LOWER(r.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(r.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            r.id,
            r.codigo,
            r.nombre,
            r.descripcion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            (
                SELECT COUNT(*)
                FROM public.auth_rol_permiso rp
                INNER JOIN public.auth_permiso p ON rp.id_permiso = p.id
                WHERE rp.id_rol = r.id AND rp.estado = 1 AND p.estado = 1
            ) AS total_permisos,
            (
                SELECT COUNT(*)
                FROM public.auth_usuario_rol ur
                INNER JOIN public.auth_usuario u ON ur.id_usuario = u.id
                WHERE ur.id_rol = r.id AND ur.estado = 1 AND u.estado = 1
            ) AS total_usuarios
        FROM public.auth_rol r
        WHERE (p_estado IS NULL OR r.estado = p_estado)
          AND (
              p_busqueda = ''
              OR LOWER(r.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(r.nombre) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY r.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'total_permisos_sistema', v_total_permisos_sistema,
        'resumen', json_build_object(
            'total', v_total_global,
            'activos', v_activos,
            'inactivos', v_inactivos
        )
    );
END;
$function$;