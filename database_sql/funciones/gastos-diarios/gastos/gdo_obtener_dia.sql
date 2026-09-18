-- Traigo el gasto de un día con todas sus líneas.
--
-- Es la pantalla principal del módulo: el cajero abre el día y va agregando
-- compras. Devuelvo cabecera + detalle en una sola llamada porque siempre se
-- muestran juntos.
CREATE OR REPLACE FUNCTION gdo_obtener_dia(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_dia JSON;
    v_detalle JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(x) INTO v_dia
    FROM (
        SELECT
            d.id,
            d.id_sucursal,
            s.nombre AS nombre_sucursal,
            d.id_turno,
            c.nombre AS nombre_caja,
            t.estado_turno,
            d.fecha_gasto,
            d.anio,
            d.mes,
            d.total_efectivo,
            d.total_yape,
            d.total_credito,
            d.total_general,
            d.observacion,
            d.estado,
            d.fecha_creacion,
            TRIM(COALESCE(uc.nombres, '') || ' ' || COALESCE(uc.apellidos, '')) AS nombre_usuario_creacion
        FROM gdo_gasto_dia d
        LEFT JOIN gen_sucursal s ON d.id_sucursal = s.id
        LEFT JOIN caj_turno t ON d.id_turno = t.id
        LEFT JOIN caj_caja c ON t.id_caja = c.id
        LEFT JOIN auth_usuario uc ON d.id_usuario_creacion = uc.id
        WHERE d.id = p_id
    ) x;

    IF v_dia IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(y) ORDER BY y.id), '[]'::JSON)
    INTO v_detalle
    FROM (
        SELECT
            det.id,
            det.id_insumo,
            i.nombre AS nombre_insumo,
            i.id_categoria,
            cat.nombre AS nombre_categoria,
            det.id_unidad_medida,
            um.nombre AS nombre_unidad,
            um.simbolo AS simbolo_unidad,
            det.cantidad,
            det.precio_unitario,
            det.subtotal,
            det.forma_pago,
            CASE det.forma_pago
                WHEN 1 THEN 'Efectivo'
                WHEN 2 THEN 'Yape'
                ELSE 'Crédito'
            END AS forma_pago_nombre,
            det.id_proveedor,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) AS nombre_proveedor,
            det.id_cxp_movimiento,
            det.observacion,
            det.estado,
            det.fecha_creacion
        FROM gdo_gasto_detalle det
        INNER JOIN gdo_insumo i ON det.id_insumo = i.id
        INNER JOIN gdo_categoria cat ON i.id_categoria = cat.id
        LEFT JOIN pro_unidad_medida um ON det.id_unidad_medida = um.id
        LEFT JOIN cli_persona p ON det.id_proveedor = p.id
        WHERE det.id_gasto_dia = p_id AND det.estado = 1
    ) y;

    RETURN json_build_object(
        'registro', json_build_object('dia', v_dia, 'detalle', v_detalle)
    );
END;
$function$;
