-- Listo el historial de turnos, con filtros por caja, cajero, estado y fechas.
--
-- No calculo los totales de cada fila acá: serían cuatro subconsultas por turno
-- y el historial se vuelve lento. Muestro lo que ya está guardado en la tabla
-- (apertura, cierre y diferencia), que es justo lo que se necesita ver en una
-- lista. Para el detalle completo está caj_resumen_turno.
CREATE OR REPLACE FUNCTION caj_listar_turnos(
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_caja BIGINT DEFAULT NULL,
    p_id_cajero BIGINT DEFAULT NULL,
    p_estado_turno INT DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_cant_abiertos BIGINT;
    v_cant_cerrados BIGINT;
    v_descuadres BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*) FILTER (WHERE t.estado_turno = 1),
        COUNT(*) FILTER (WHERE t.estado_turno = 2),
        -- Turnos cerrados que no cuadraron. Es el número que el administrador
        -- mira primero cuando entra a revisar caja.
        COUNT(*) FILTER (WHERE t.estado_turno = 2 AND COALESCE(t.monto_diferencia, 0) <> 0)
    INTO v_cant_abiertos, v_cant_cerrados, v_descuadres
    FROM caj_turno t
    WHERE t.estado = 1
      AND (p_id_caja IS NULL OR t.id_caja = p_id_caja);

    SELECT COUNT(*) INTO v_total
    FROM caj_turno t
    WHERE t.estado = 1
      AND (p_id_caja IS NULL OR t.id_caja = p_id_caja)
      AND (p_id_cajero IS NULL OR t.id_cajero = p_id_cajero)
      AND (p_estado_turno IS NULL OR t.estado_turno = p_estado_turno)
      AND (p_fecha_desde IS NULL OR t.fecha_apertura >= p_fecha_desde)
      -- Sumo un día al "hasta" para que incluya todo ese día: si filtro
      -- hasta el 15, un turno abierto el 15 a las 20:00 tiene que entrar.
      AND (p_fecha_hasta IS NULL OR t.fecha_apertura < (p_fecha_hasta + 1));

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            tu.id,
            tu.id_caja,
            c.codigo AS codigo_caja,
            c.nombre AS nombre_caja,
            tu.id_cajero,
            TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, '')) AS nombre_cajero,
            tu.monto_apertura,
            tu.fecha_apertura,
            tu.monto_cierre_sistema,
            tu.monto_cierre_declarado,
            tu.monto_diferencia,
            tu.fecha_cierre,
            tu.estado_turno,
            lo.nombre AS estado_turno_nombre,
            tu.observacion,
            tu.estado
        FROM caj_turno tu
        INNER JOIN caj_caja c ON tu.id_caja = c.id
        INNER JOIN auth_usuario u ON tu.id_cajero = u.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = tu.estado_turno
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'TURNO_ESTADO')
        WHERE tu.estado = 1
          AND (p_id_caja IS NULL OR tu.id_caja = p_id_caja)
          AND (p_id_cajero IS NULL OR tu.id_cajero = p_id_cajero)
          AND (p_estado_turno IS NULL OR tu.estado_turno = p_estado_turno)
          AND (p_fecha_desde IS NULL OR tu.fecha_apertura >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR tu.fecha_apertura < (p_fecha_hasta + 1))
        -- Los abiertos primero, después por fecha más reciente.
        ORDER BY tu.estado_turno ASC, tu.fecha_apertura DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'abiertos', v_cant_abiertos,
            'cerrados', v_cant_cerrados,
            'con_descuadre', v_descuadres
        )
    );
END;
$function$;
