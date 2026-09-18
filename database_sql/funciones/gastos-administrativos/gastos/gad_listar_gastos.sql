-- Listo los gastos administrativos con filtros por categoría, tipo y período.
--
-- El filtro por categoría incluye a sus subcategorías: si el usuario filtra
-- por "Servicios básicos" espera ver la luz, el agua y el internet, no una
-- lista vacía porque los gastos cuelgan de las hijas.
--
-- El resumen desglosa por tipo (fijo/variable) y por medio de pago, que son
-- las dos preguntas del cierre mensual: cuánto es estructura fija y cuánto
-- salió del cajón.
CREATE OR REPLACE FUNCTION gad_listar_gastos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_categoria BIGINT DEFAULT NULL,
    p_tipo_gasto INT DEFAULT NULL,
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL,
    p_medio_pago INT DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_monto_total NUMERIC(12,2);
    v_fijos NUMERIC(12,2);
    v_variables NUMERIC(12,2);
    v_efectivo NUMERIC(12,2);
    v_yape NUMERIC(12,2);
    v_tarjeta NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        COALESCE(SUM(g.monto), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE c.tipo_gasto = 1), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE c.tipo_gasto = 2), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE g.medio_pago = 1), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE g.medio_pago = 2), 0),
        COALESCE(SUM(g.monto) FILTER (WHERE g.medio_pago = 3), 0)
    INTO v_total, v_monto_total, v_fijos, v_variables, v_efectivo, v_yape, v_tarjeta
    FROM gad_gasto g
    INNER JOIN gad_categoria c ON g.id_categoria = c.id
    WHERE g.estado = 1
      AND (
          p_id_categoria IS NULL
          OR g.id_categoria = p_id_categoria
          OR c.id_categoria_padre = p_id_categoria
      )
      AND (p_tipo_gasto IS NULL OR c.tipo_gasto = p_tipo_gasto)
      AND (p_anio IS NULL OR g.anio = p_anio)
      AND (p_mes IS NULL OR g.mes = p_mes)
      AND (p_medio_pago IS NULL OR g.medio_pago = p_medio_pago)
      AND (p_fecha_desde IS NULL OR g.fecha_gasto >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR g.fecha_gasto <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR LOWER(g.concepto) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(g.num_comprobante, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            g.id,
            g.id_categoria,
            c.nombre AS nombre_categoria,
            p.nombre AS nombre_categoria_padre,
            c.tipo_gasto,
            CASE c.tipo_gasto WHEN 1 THEN 'Fijo' ELSE 'Variable' END AS tipo_gasto_nombre,
            g.concepto,
            g.monto,
            g.fecha_gasto,
            g.anio,
            g.mes,
            g.medio_pago,
            lo.nombre AS medio_pago_nombre,
            g.num_comprobante,
            g.id_persona,
            per.razon_social,
            g.id_turno,
            g.observacion,
            g.estado,
            g.fecha_creacion
        FROM gad_gasto g
        INNER JOIN gad_categoria c ON g.id_categoria = c.id
        LEFT JOIN gad_categoria p ON c.id_categoria_padre = p.id
        LEFT JOIN cli_persona per ON g.id_persona = per.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = g.medio_pago
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'MEDIO_PAGO')
        WHERE g.estado = 1
          AND (
              p_id_categoria IS NULL
              OR g.id_categoria = p_id_categoria
              OR c.id_categoria_padre = p_id_categoria
          )
          AND (p_tipo_gasto IS NULL OR c.tipo_gasto = p_tipo_gasto)
          AND (p_anio IS NULL OR g.anio = p_anio)
          AND (p_mes IS NULL OR g.mes = p_mes)
          AND (p_medio_pago IS NULL OR g.medio_pago = p_medio_pago)
          AND (p_fecha_desde IS NULL OR g.fecha_gasto >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR g.fecha_gasto <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR LOWER(g.concepto) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(g.num_comprobante, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY g.fecha_gasto DESC, g.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'monto_total', v_monto_total,
            'fijos', v_fijos,
            'variables', v_variables,
            'efectivo', v_efectivo,
            'yape', v_yape,
            'tarjeta', v_tarjeta,
            'cantidad', v_total
        )
    );
END;
$function$;
