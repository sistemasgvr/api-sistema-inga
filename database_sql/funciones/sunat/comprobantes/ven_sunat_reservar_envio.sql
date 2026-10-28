-- Reserva una boleta/factura pendiente para su envío individual: pasa a «en proceso»
-- (5) y solo el primero que llega la obtiene, así no se envía dos veces a la vez.
DROP FUNCTION IF EXISTS ven_sunat_reservar_envio(p_id_comprobante BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_reservar_envio(p_id_comprobante BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    UPDATE ven_comprobante
    SET estado_sunat = 5,
        forma_envio = 1,
        intentos_envio = intentos_envio + 1,
        fecha_envio_sunat = CURRENT_TIMESTAMP
    WHERE id = p_id_comprobante
      AND estado = 1
      AND tipo_comprobante IN (1, 2)
      AND estado_sunat = 1
    RETURNING id INTO v_id;

    RETURN json_build_object('reservado', v_id IS NOT NULL);
END;
$function$;
