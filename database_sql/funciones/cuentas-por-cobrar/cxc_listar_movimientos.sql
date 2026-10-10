CREATE OR REPLACE FUNCTION cxc_listar_movimientos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_persona BIGINT DEFAULT NULL,
    p_id_convenio BIGINT DEFAULT NULL,
    p_tipo SMALLINT DEFAULT NULL,
    p_anio SMALLINT DEFAULT NULL,
    p_mes SMALLINT DEFAULT NULL,
    p_quincena SMALLINT DEFAULT NULL,
    p_incluir_anulados BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_cargos NUMERIC(12,2);
    v_abonos NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*),
           COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1 AND m.estado = 1), 0),
           COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2 AND m.estado = 1), 0)
    INTO v_total, v_cargos, v_abonos
    FROM cxc_movimiento m
    INNER JOIN cli_persona p ON m.id_persona = p.id
    WHERE (p_incluir_anulados = TRUE OR m.estado = 1)
      AND (p_id_persona IS NULL OR m.id_persona = p_id_persona)
      AND (p_id_convenio IS NULL OR m.id_convenio = p_id_convenio)
      AND (p_tipo IS NULL OR m.tipo_movimiento = p_tipo)
      AND (p_anio IS NULL OR m.anio = p_anio)
      AND (p_mes IS NULL OR m.mes = p_mes)
      AND (p_quincena IS NULL OR m.quincena = p_quincena)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(p.nombres || ' ' || p.apellido_paterno, p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR COALESCE(p.num_documento, '') LIKE '%' || p_busqueda || '%'
          OR LOWER(COALESCE(m.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.id_persona,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) AS nombre_persona,
            p.num_documento,
            m.id_convenio,
            c.nombre AS nombre_convenio,
            m.tipo_movimiento,
            CASE m.tipo_movimiento
                WHEN 1 THEN 'Consumo'
                WHEN 2 THEN 'Abono'
                ELSE 'Ajuste'
            END AS tipo_movimiento_nombre,
            m.monto,
            m.saldo_resultante,
            m.anio,
            m.mes,
            m.quincena,
            m.id_pedido,
            m.observacion,
            -- Qué se pidió en el pedido que originó el cargo. Sale por JOIN, no copiado
            -- a una tabla propia: el detalle de un pedido cerrado ya es inmutable y el
            -- cargo no siempre es el pedido entero (con tope, parte del total va a
            -- crédito y el resto en efectivo). El LATERAL solo corre si hay pedido, así
            -- que abonos y ajustes no pagan el costo.
            items.detalle AS detalle_pedido,
            m.estado,
            m.fecha_creacion,
            TRIM(COALESCE(uc.nombres, '') || ' ' || COALESCE(uc.apellidos, '')) AS nombre_usuario_creacion
        FROM cxc_movimiento m
        INNER JOIN cli_persona p ON m.id_persona = p.id
        LEFT JOIN cli_convenio c ON m.id_convenio = c.id
        LEFT JOIN auth_usuario_datos uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN LATERAL (
            SELECT string_agg(
                     trim(trailing '.' FROM trim(trailing '0' FROM to_char(x.cantidad, 'FM999990.99')))
                         || 'x ' || pr.nombre,
                     ', ' ORDER BY pr.nombre) AS detalle
              FROM (
                  -- Un producto puede estar repartido en varias líneas del pedido;
                  -- sin este GROUP BY salía repetido ("1x Arroz, 1x Arroz").
                  SELECT d.id_producto, SUM(d.cantidad - d.cantidad_cancelada) AS cantidad
                    FROM ven_pedido_detalle d
                   WHERE d.id_pedido = m.id_pedido
                     AND d.estado = 1
                     AND d.tipo_linea <> 3
                     AND d.cantidad > d.cantidad_cancelada
                   GROUP BY d.id_producto
              ) x
              JOIN pro_producto pr ON pr.id = x.id_producto
        ) items ON TRUE
        WHERE (p_incluir_anulados = TRUE OR m.estado = 1)
          AND (p_id_persona IS NULL OR m.id_persona = p_id_persona)
          AND (p_id_convenio IS NULL OR m.id_convenio = p_id_convenio)
          AND (p_tipo IS NULL OR m.tipo_movimiento = p_tipo)
          AND (p_anio IS NULL OR m.anio = p_anio)
          AND (p_mes IS NULL OR m.mes = p_mes)
          AND (p_quincena IS NULL OR m.quincena = p_quincena)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(p.nombres || ' ' || p.apellido_paterno, p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR COALESCE(p.num_documento, '') LIKE '%' || p_busqueda || '%'
              OR LOWER(COALESCE(m.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY m.fecha_creacion DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total_cargos', v_cargos,
            'total_abonos', v_abonos,
            'saldo_periodo', v_cargos - v_abonos
        )
    );
END;
$function$;
