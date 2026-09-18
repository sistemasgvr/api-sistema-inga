-- Traigo un movimiento de CxC por ID.
-- Registrar consumo, abono y ajuste terminan llamando acá para devolver
-- siempre el mismo shape.
CREATE OR REPLACE FUNCTION cxc_obtener_movimiento(p_id BIGINT)
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
            ) AS nombre_persona,
            p.num_documento,
            m.id_convenio,
            c.nombre AS nombre_convenio,
            c.limite_credito,
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
            m.id_pago,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            TRIM(COALESCE(uc.nombres, '') || ' ' || COALESCE(uc.apellidos, '')) AS nombre_usuario_creacion
        FROM cxc_movimiento m
        INNER JOIN cli_persona p ON m.id_persona = p.id
        LEFT JOIN cli_convenio c ON m.id_convenio = c.id
        LEFT JOIN auth_usuario uc ON m.id_usuario_creacion = uc.id
        WHERE m.id = p_id
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
