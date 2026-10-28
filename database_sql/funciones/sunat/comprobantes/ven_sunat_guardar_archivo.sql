-- Ruta en Storage del XML o PDF A4 generado bajo demanda. Solo se guarda la primera:
-- si dos descargas llegan a la vez, gana la que archivó antes.
-- p_tipo: 'XML' o 'PDF_A4'.
DROP FUNCTION IF EXISTS ven_sunat_guardar_archivo(p_id_comprobante BIGINT, p_tipo VARCHAR, p_ruta TEXT);
CREATE OR REPLACE FUNCTION ven_sunat_guardar_archivo(
    p_id_comprobante BIGINT,
    p_tipo VARCHAR,
    p_ruta TEXT
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_tipo = 'XML' THEN
        UPDATE ven_comprobante
        SET ruta_xml = p_ruta
        WHERE id = p_id_comprobante
          AND ruta_xml IS NULL;
    ELSIF p_tipo = 'PDF_A4' THEN
        UPDATE ven_comprobante
        SET ruta_pdf_a4 = p_ruta
        WHERE id = p_id_comprobante
          AND ruta_pdf_a4 IS NULL;
    ELSE
        RETURN json_build_object('error', 'Tipo de archivo inválido');
    END IF;

    RETURN json_build_object('actualizado', FOUND);
END;
$function$;
