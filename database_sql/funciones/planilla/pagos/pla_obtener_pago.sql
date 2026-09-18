-- Traigo un pago de planilla por ID, con los datos del trabajador y del turno.
-- Registrar y anular terminan llamando acá para devolver siempre el mismo shape.
CREATE OR REPLACE FUNCTION pla_obtener_pago(p_id BIGINT)
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
            p.id,
            p.id_trabajador,
            TRIM(t.nombres || ' ' || t.apellidos) AS nombre_trabajador,
            t.puesto,
            t.num_documento,
            p.fecha_pago,
            p.anio,
            p.mes,
            p.quincena,
            p.monto,
            p.medio_pago,
            lo.nombre AS medio_pago_nombre,
            p.id_turno,
            c.nombre AS nombre_caja,
            p.observacion,
            p.estado,
            p.fecha_creacion,
            p.id_usuario_creacion,
            TRIM(COALESCE(uc.nombres, '') || ' ' || COALESCE(uc.apellidos, '')) AS nombre_usuario_creacion
        FROM pla_pago p
        INNER JOIN pla_trabajador t ON p.id_trabajador = t.id
        LEFT JOIN caj_turno tu ON p.id_turno = tu.id
        LEFT JOIN caj_caja c ON tu.id_caja = c.id
        LEFT JOIN auth_usuario uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = p.medio_pago
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'MEDIO_PAGO')
        WHERE p.id = p_id
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
