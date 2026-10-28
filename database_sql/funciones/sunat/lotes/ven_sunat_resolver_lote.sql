-- Cierra el lote con la respuesta de SUNAT y actualiza sus comprobantes:
--   aceptado:  las boletas adicionadas quedan aceptadas (2) y las anuladas, anuladas (4);
--   rechazado: las boletas vuelven a pendientes (1) para otro envío y las bajas dejan
--              el comprobante como estaba (aceptado), con el motivo en el mensaje.
-- p_datos: codigo, mensaje, ruta_cdr.
DROP FUNCTION IF EXISTS ven_sunat_resolver_lote(p_id_lote BIGINT, p_aceptado BOOLEAN, p_datos JSONB);
CREATE OR REPLACE FUNCTION ven_sunat_resolver_lote(
    p_id_lote BIGINT,
    p_aceptado BOOLEAN,
    p_datos JSONB DEFAULT '{}'::JSONB
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo VARCHAR(10) := LEFT(NULLIF(p_datos->>'codigo', ''), 10);
    v_mensaje TEXT := NULLIF(p_datos->>'mensaje', '');
BEGIN
    UPDATE ven_sunat_lote
    SET estado_sunat = CASE WHEN p_aceptado THEN 2 ELSE 3 END,
        codigo_respuesta_sunat = v_codigo,
        sunat_mensaje = v_mensaje,
        ruta_cdr = COALESCE(NULLIF(p_datos->>'ruta_cdr', ''), ruta_cdr),
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = p_id_lote;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El lote no existe');
    END IF;

    UPDATE ven_comprobante c
    SET estado_sunat = CASE
            WHEN d.estado_item = 1 AND p_aceptado THEN 2
            WHEN d.estado_item = 1 THEN 1
            WHEN p_aceptado THEN 4
            ELSE c.estado_sunat
        END,
        codigo_respuesta_sunat = CASE
            WHEN p_aceptado THEN COALESCE(v_codigo, c.codigo_respuesta_sunat)
            ELSE c.codigo_respuesta_sunat
        END,
        sunat_mensaje = CASE
            WHEN d.estado_item = 1 AND p_aceptado THEN 'Aceptado en el resumen ' || l.identificador
            WHEN d.estado_item = 1 THEN 'Resumen ' || l.identificador || ' no aceptado: ' || COALESCE(v_mensaje, 'sin detalle')
            WHEN p_aceptado THEN 'Baja aceptada (' || l.identificador || ')'
            ELSE 'Baja ' || l.identificador || ' no aceptada: ' || COALESCE(v_mensaje, 'sin detalle')
        END,
        fecha_modificacion = CURRENT_TIMESTAMP
    FROM ven_sunat_lote_detalle d
    INNER JOIN ven_sunat_lote l ON l.id = d.id_lote
    WHERE d.id_lote = p_id_lote
      AND c.id = d.id_comprobante;

    RETURN json_build_object('actualizado', TRUE);
END;
$function$;
