CREATE OR REPLACE FUNCTION auth_listar_permisos(
    p_busqueda VARCHAR DEFAULT '',
    p_modulo VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    SELECT COUNT(*) INTO v_total
    FROM auth_permiso p
    WHERE p.estado = 1
      AND (p_modulo IS NULL OR UPPER(p.modulo) = UPPER(p_modulo))
      AND (
          p_busqueda = ''
          OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.modulo) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.codigo,
            p.nombre,
            p.descripcion,
            p.modulo,
            p.estado
        FROM auth_permiso p
        WHERE p.estado = 1
          AND (p_modulo IS NULL OR UPPER(p.modulo) = UPPER(p_modulo))
          AND (
              p_busqueda = ''
              OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.modulo) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY p.modulo ASC, p.codigo ASC
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
