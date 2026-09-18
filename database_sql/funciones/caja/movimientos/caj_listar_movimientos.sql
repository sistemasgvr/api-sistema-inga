-- Listo los movimientos de un turno.
--
-- Sin paginar: un turno tiene unos pocos movimientos (gastos y retiros del día),
-- no cientos. Paginarlos sería complicar la pantalla sin ganar nada.
CREATE OR REPLACE FUNCTION caj_listar_movimientos(p_id_turno BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_ingresos NUMERIC(12,2);
    v_egresos NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COALESCE(SUM(monto) FILTER (WHERE tipo_movimiento = 1), 0),
        COALESCE(SUM(monto) FILTER (WHERE tipo_movimiento = 2), 0)
    INTO v_ingresos, v_egresos
    FROM caj_movimiento
    WHERE id_turno = p_id_turno AND estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha_creacion DESC), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            m.id,
            m.id_turno,
            m.tipo_movimiento,
            lo.nombre AS tipo_movimiento_nombre,
            m.monto,
            m.motivo,
            m.id_usuario_autoriza,
            TRIM(COALESCE(ua.nombres, '') || ' ' || COALESCE(ua.apellidos, '')) AS nombre_autoriza,
            m.id_usuario_creacion,
            TRIM(COALESCE(uc.nombres, '') || ' ' || COALESCE(uc.apellidos, '')) AS nombre_registra,
            m.fecha_creacion
        FROM caj_movimiento m
        LEFT JOIN auth_usuario ua ON m.id_usuario_autoriza = ua.id
        LEFT JOIN auth_usuario uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = m.tipo_movimiento
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'CAJA_MOV_TIPO')
        WHERE m.id_turno = p_id_turno AND m.estado = 1
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'resumen', json_build_object(
            'ingresos', v_ingresos,
            'egresos', v_egresos,
            'neto', v_ingresos - v_egresos
        )
    );
END;
$function$;
