-- Envíos individuales que quedaron «en proceso» sin respuesta (p. ej. el API se
-- reinició a mitad del envío): vuelven a pendientes para reintentarlos.
DROP FUNCTION IF EXISTS ven_sunat_liberar_envios_colgados();
CREATE OR REPLACE FUNCTION ven_sunat_liberar_envios_colgados()
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_liberados INTEGER;
BEGIN
    UPDATE ven_comprobante
    SET estado_sunat = 1,
        sunat_mensaje = 'El envío anterior no terminó; se reintentará'
    WHERE estado_sunat = 5
      AND forma_envio = 1
      AND fecha_envio_sunat < CURRENT_TIMESTAMP - INTERVAL '10 minutes';

    GET DIAGNOSTICS v_liberados = ROW_COUNT;
    RETURN json_build_object('liberados', v_liberados);
END;
$function$;
