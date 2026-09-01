CREATE OR REPLACE FUNCTION gen_listar_estaciones(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_sucursal BIGINT DEFAULT NULL,
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
    SET TIME ZONE 'America/Lima';

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE e.estado = 1),
        COUNT(*) FILTER (WHERE e.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM gen_estacion e
    INNER JOIN gen_sucursal s ON e.id_sucursal = s.id
    WHERE s.estado = 1
      AND (p_id_sucursal IS NULL OR e.id_sucursal = p_id_sucursal)
      AND (
          p_busqueda = ''
          OR LOWER(e.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(e.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COUNT(*) INTO v_total
    FROM gen_estacion e
    INNER JOIN gen_sucursal s ON e.id_sucursal = s.id
    WHERE (p_estado IS NULL OR e.estado = p_estado)
      AND s.estado = 1
      AND (p_id_sucursal IS NULL OR e.id_sucursal = p_id_sucursal)
      AND (
          p_busqueda = ''
          OR LOWER(e.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(e.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            e.id,
            e.id_sucursal,
            s.nombre AS nombre_sucursal,
            e.codigo,
            e.nombre,
            e.tipo_estacion,
            lo.nombre AS tipo_estacion_nombre,
            e.impresora_nombre,
            e.impresora_ip,
            e.usa_kds,
            e.estado,
            e.fecha_creacion,
            e.fecha_modificacion,
            e.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            e.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM gen_estacion e
        INNER JOIN gen_sucursal s ON e.id_sucursal = s.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = e.tipo_estacion 
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'ESTACION_TIPO')
        LEFT JOIN auth_usuario uc ON e.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um ON e.id_usuario_modificacion = um.id
        WHERE (p_estado IS NULL OR e.estado = p_estado)
          AND s.estado = 1
          AND (p_id_sucursal IS NULL OR e.id_sucursal = p_id_sucursal)
          AND (
              p_busqueda = ''
              OR LOWER(e.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(e.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(s.nombre) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY e.nombre ASC
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