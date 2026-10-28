-- Guarda la respuesta de SUNAT del comprobante. Hash, XML, CDR y código solo se
-- reemplazan cuando llegan (NULL conserva lo anterior).
-- p_datos: estado_sunat, codigo, mensaje, observaciones, hash, ruta_xml, ruta_cdr.
DROP FUNCTION IF EXISTS ven_sunat_guardar_resultado(p_id_comprobante BIGINT, p_datos JSONB);
CREATE OR REPLACE FUNCTION ven_sunat_guardar_resultado(
    p_id_comprobante BIGINT,
    p_datos JSONB
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    IF (p_datos->>'estado_sunat')::SMALLINT NOT IN (1, 2, 3, 4, 5) THEN
        RETURN json_build_object('error', 'Estado SUNAT inválido');
    END IF;

    UPDATE ven_comprobante
    SET estado_sunat = (p_datos->>'estado_sunat')::SMALLINT,
        codigo_respuesta_sunat = COALESCE(NULLIF(p_datos->>'codigo', ''), codigo_respuesta_sunat),
        sunat_mensaje = p_datos->>'mensaje',
        observaciones_sunat = p_datos->>'observaciones',
        hash_qr = COALESCE(NULLIF(p_datos->>'hash', ''), hash_qr),
        ruta_xml = COALESCE(NULLIF(p_datos->>'ruta_xml', ''), ruta_xml),
        ruta_cdr = COALESCE(NULLIF(p_datos->>'ruta_cdr', ''), ruta_cdr),
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = p_id_comprobante;

    RETURN json_build_object('actualizado', FOUND);
END;
$function$;
