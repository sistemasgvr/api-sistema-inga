-- Traigo un turno con sus totales ya calculados.
--
-- Mezclo la fila del turno con lo que devuelve caj_calcular_totales_turno para
-- que el panel del turno activo tenga todo en una sola llamada: cuánto se abrió,
-- cuánto se vendió por cada medio y cuánto efectivo debería haber en el cajón.
CREATE OR REPLACE FUNCTION caj_obtener_turno(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSONB;
    v_totales JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT to_jsonb(t) INTO v_registro
    FROM (
        SELECT
            tu.id,
            tu.id_caja,
            c.codigo AS codigo_caja,
            c.nombre AS nombre_caja,
            c.id_sucursal,
            s.nombre AS nombre_sucursal,
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
        INNER JOIN gen_sucursal s ON c.id_sucursal = s.id
        INNER JOIN auth_usuario u ON tu.id_cajero = u.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = tu.estado_turno
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'TURNO_ESTADO')
        WHERE tu.id = p_id
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    v_totales := caj_calcular_totales_turno(p_id)::JSONB;

    -- Uso jsonb para poder concatenar los dos objetos con ||.
    -- Quito 'monto_apertura' de los totales porque ya viene en el registro y
    -- no quiero el mismo dato dos veces con el riesgo de que se contradigan.
    RETURN json_build_object(
        'registro', v_registro || (v_totales - 'monto_apertura')
    );
END;
$function$;
