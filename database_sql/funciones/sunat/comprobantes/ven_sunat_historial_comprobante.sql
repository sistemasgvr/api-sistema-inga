-- Envíos y respuestas SUNAT de un comprobante, incluidos los de sus resúmenes y bajas.
DROP FUNCTION IF EXISTS ven_sunat_historial_comprobante(p_id_comprobante BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_historial_comprobante(p_id_comprobante BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            l.id,
            l.operacion,
            l.exito,
            l.codigo,
            l.mensaje,
            l.id_lote,
            l.fecha_creacion
        FROM ven_comprobante_sunat_log l
        WHERE l.id_comprobante = p_id_comprobante
           OR l.id_lote IN (
               SELECT d.id_lote
               FROM ven_sunat_lote_detalle d
               WHERE d.id_comprobante = p_id_comprobante
           )
        ORDER BY l.id DESC
        LIMIT 50
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
