-- Traigo un movimiento de CxP por ID.
-- Registrar cargo, registrar abono y anular terminan llamando acá para
-- devolver siempre el mismo shape.
CREATE OR REPLACE FUNCTION cxp_obtener_movimiento(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(x) INTO v_registro
    FROM (
        SELECT
            m.id,
            m.id_persona,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) AS nombre_proveedor,
            p.num_documento,
            m.tipo_movimiento,
            CASE m.tipo_movimiento
                WHEN 1 THEN 'Cargo'
                WHEN 2 THEN 'Abono'
                ELSE 'Ajuste'
            END AS tipo_movimiento_nombre,
            m.monto,
            m.saldo_resultante,
            m.medio_pago,
            lo.nombre AS medio_pago_nombre,
            m.fecha_movimiento,
            m.anio,
            m.mes,
            m.semana,
            m.num_comprobante,
            m.id_gasto_diario,
            m.id_turno,
            c.nombre AS nombre_caja,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            TRIM(COALESCE(uc.nombres, '') || ' ' || COALESCE(uc.apellidos, '')) AS nombre_usuario_creacion
        FROM cxp_movimiento m
        INNER JOIN cli_persona p ON m.id_persona = p.id
        LEFT JOIN caj_turno tu ON m.id_turno = tu.id
        LEFT JOIN caj_caja c ON tu.id_caja = c.id
        LEFT JOIN auth_usuario uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = m.medio_pago
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'MEDIO_PAGO')
        WHERE m.id = p_id
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
