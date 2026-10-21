DROP FUNCTION IF EXISTS caj_listar_cajas(
    p_busqueda VARCHAR,
    p_limite INTEGER,
    p_offset INTEGER,
    p_id_sucursal BIGINT,
    p_estado INT
);

CREATE OR REPLACE FUNCTION caj_listar_cajas(
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
    v_cant_abiertas BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE c.estado = 1),
        COUNT(*) FILTER (WHERE c.estado = 0),
        COUNT(*) FILTER (WHERE c.estado = 1 AND ta.id IS NOT NULL)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos, v_cant_abiertas
    FROM caj_caja c
    LEFT JOIN LATERAL (
        SELECT t2.id
        FROM caj_turno t2
        WHERE t2.id_caja = c.id AND t2.estado_turno = 1 AND t2.estado = 1
        LIMIT 1
    ) ta ON TRUE
    WHERE (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal);

    SELECT COUNT(*) INTO v_total
    FROM caj_caja c
    WHERE (p_estado IS NULL OR c.estado = p_estado)
      AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
      AND (
          p_busqueda = ''
          OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_sucursal,
            s.nombre AS nombre_sucursal,
            c.nombre,
            c.estado,
            ta.id AS id_turno_abierto,
            ta.fecha_apertura AS turno_fecha_apertura,
            ta.monto_apertura AS turno_monto_apertura,
            ta.id_cajero AS turno_id_cajero,
            TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, '')) AS turno_cajero,
            (ta.id IS NOT NULL) AS tiene_turno_abierto,
            c.fecha_creacion,
            c.fecha_modificacion
        FROM caj_caja c
        INNER JOIN gen_sucursal s ON c.id_sucursal = s.id
        -- LEFT JOIN LATERAL para traer el turno abierto (si hay) sin duplicar
        -- la fila de la caja. El índice uq_caj_turno_abierto garantiza que
        -- como máximo haya uno, pero el LIMIT 1 lo deja explícito.
        LEFT JOIN LATERAL (
            SELECT t2.id, t2.fecha_apertura, t2.monto_apertura, t2.id_cajero
            FROM caj_turno t2
            WHERE t2.id_caja = c.id AND t2.estado_turno = 1 AND t2.estado = 1
            LIMIT 1
        ) ta ON TRUE
        LEFT JOIN auth_usuario_datos u ON ta.id_cajero = u.id
        WHERE (p_estado IS NULL OR c.estado = p_estado)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND (
              p_busqueda = ''
              OR LOWER(c.nombre) LIKE LOWER('%' || p_busqueda || '%')
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
            'inactivos', v_cant_inactivos,
            'abiertas', v_cant_abiertas
        )
    );
END;
$function$;
