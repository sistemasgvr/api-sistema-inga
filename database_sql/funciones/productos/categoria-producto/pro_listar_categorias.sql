
CREATE OR REPLACE FUNCTION pro_listar_categorias(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_solo_activos INTEGER DEFAULT 1,
    p_es_carta BOOLEAN DEFAULT NULL
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
    SET TIME ZONE 'America/Lima';

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE c.estado = 1),
        COUNT(*) FILTER (WHERE c.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM pro_categoria c;

    SELECT COUNT(*) INTO v_total
    FROM pro_categoria c
    WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
      AND (p_es_carta IS NULL OR c.es_carta = p_es_carta)
      AND (
          p_busqueda = ''
          OR LOWER(c.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.codigo,
            c.nombre,
            c.descripcion,
            c.es_carta,
            c.orden,
            c.estado,
            (
                SELECT COUNT(*)
                FROM pro_subcategoria sc
                WHERE sc.id_categoria = c.id AND sc.estado = 1
            ) AS total_subcategorias,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um2.nombres AS nombre_usuario_modificacion
        FROM pro_categoria c
        LEFT JOIN auth_usuario uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um2 ON c.id_usuario_modificacion = um2.id
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_es_carta IS NULL OR c.es_carta = p_es_carta)
          AND (
              p_busqueda = ''
              OR LOWER(c.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.orden ASC, c.nombre ASC
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