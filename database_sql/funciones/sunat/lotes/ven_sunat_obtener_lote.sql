-- Detalle de un resumen o baja con sus comprobantes. Incluye las rutas de Storage
-- (ruta_xml, ruta_cdr) para las descargas; el API no las entrega al front.
DROP FUNCTION IF EXISTS ven_sunat_obtener_lote(p_id_lote BIGINT);
DROP FUNCTION IF EXISTS ven_sunat_obtener_lote(p_id_lote BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_obtener_lote(
    p_id_lote BIGINT,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'id', l.id,
        'id_empresa', l.id_empresa,
        'tipo_lote', l.tipo_lote,
        'identificador', l.identificador,
        'fecha_documentos', l.fecha_documentos,
        'fecha_envio', l.fecha_envio,
        'ticket', l.ticket,
        'estado_sunat', l.estado_sunat,
        'codigo_respuesta_sunat', l.codigo_respuesta_sunat,
        'sunat_mensaje', l.sunat_mensaje,
        'ruta_xml', l.ruta_xml,
        'ruta_cdr', l.ruta_cdr,
        'fecha_creacion', l.fecha_creacion,
        'comprobantes', COALESCE((
            SELECT json_agg(json_build_object(
                'id', c.id,
                'numero', c.serie || '-' || c.correlativo,
                'tipo_comprobante', c.tipo_comprobante,
                'estado_item', d.estado_item,
                'motivo', d.motivo,
                'monto_total', c.monto_total,
                'estado_sunat', c.estado_sunat
            ) ORDER BY c.serie, c.correlativo)
            FROM ven_sunat_lote_detalle d
            INNER JOIN ven_comprobante c ON c.id = d.id_comprobante
            WHERE d.id_lote = l.id
        ), '[]'::JSON)
    )
    INTO v_registro
    FROM ven_sunat_lote l
    WHERE l.id = p_id_lote
      AND (p_id_empresa IS NULL OR l.id_empresa = p_id_empresa);

    RETURN json_build_object('registro', v_registro);
END;
$function$;
