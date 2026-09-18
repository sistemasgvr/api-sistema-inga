-- Listo los convenios de crédito del consorcio (GVR, 4G, ApuSalud, Jurisconta).
--
-- Devuelvo también "personas_asignadas" porque en la pantalla necesito avisar
-- cuántos clientes dependen de cada convenio antes de que alguien lo dé de baja.
-- Si no lo mando desde acá, el front tendría que hacer una consulta por fila.
CREATE OR REPLACE FUNCTION cli_listar_convenios(
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
    SET TIME ZONE 'America/Lima';

    -- Cuento el universo completo ignorando el filtro de estado.
    -- Estos números alimentan las tarjetas de resumen de la pantalla,
    -- que deben mostrar el total real aunque el usuario esté filtrando.
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE c.estado = 1),
        COUNT(*) FILTER (WHERE c.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM cli_convenio c
    WHERE (
        p_busqueda = ''
        OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
        OR LOWER(c.codigo) LIKE LOWER('%' || p_busqueda || '%')
    );

    -- Este total sí respeta el filtro de estado: es el que usa la paginación.
    SELECT COUNT(*) INTO v_total
    FROM cli_convenio c
    WHERE (p_estado IS NULL OR c.estado = p_estado)
      AND (
          p_busqueda = ''
          OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(c.codigo) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.codigo,
            c.nombre,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            cp.dias_credito,
            c.limite_credito,
            c.corte_quincenal,
            c.estado,
            (
                SELECT COUNT(*)
                FROM cli_persona p
                WHERE p.id_convenio = c.id AND p.estado = 1
            ) AS personas_asignadas,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM cli_convenio c
        INNER JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN auth_usuario uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um ON c.id_usuario_modificacion = um.id
        WHERE (p_estado IS NULL OR c.estado = p_estado)
          AND (
              p_busqueda = ''
              OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(c.codigo) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.nombre ASC
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
