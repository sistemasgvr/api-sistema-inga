-- SUNAT recibió el resumen o la baja y devolvió su ticket: queda «en proceso» hasta
-- que la consulta del ticket traiga el CDR.
DROP FUNCTION IF EXISTS ven_sunat_registrar_ticket_lote(p_id_lote BIGINT, p_ticket VARCHAR, p_ruta_xml TEXT);
CREATE OR REPLACE FUNCTION ven_sunat_registrar_ticket_lote(
    p_id_lote BIGINT,
    p_ticket VARCHAR,
    p_ruta_xml TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE ven_sunat_lote
    SET ticket = p_ticket,
        ruta_xml = COALESCE(p_ruta_xml, ruta_xml),
        estado_sunat = 5,
        sunat_mensaje = NULL,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = p_id_lote;

    RETURN json_build_object('actualizado', FOUND);
END;
$function$;
