-- CDR del resumen diario aceptado que informó la boleta (las boletas enviadas por
-- resumen no tienen CDR propio).
DROP FUNCTION IF EXISTS ven_sunat_cdr_comprobante(p_id_comprobante BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_cdr_comprobante(p_id_comprobante BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'ruta_cdr', l.ruta_cdr,
        'identificador', l.identificador
    )
    INTO v_registro
    FROM ven_sunat_lote l
    INNER JOIN ven_sunat_lote_detalle d ON d.id_lote = l.id
    WHERE d.id_comprobante = p_id_comprobante
      AND d.estado_item = 1
      AND l.estado_sunat = 2
      AND l.ruta_cdr IS NOT NULL
    ORDER BY l.id DESC
    LIMIT 1;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
