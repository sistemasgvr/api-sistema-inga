-- Comprobantes con su estado SUNAT, rutas de archivos y líneas tributarias, para armar
-- el JSON de APIsPERU (envío individual, resumen diario o baja).
DROP FUNCTION IF EXISTS ven_sunat_obtener_comprobantes(p_ids BIGINT[]);
CREATE OR REPLACE FUNCTION ven_sunat_obtener_comprobantes(p_ids BIGINT[])
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.id), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_pedido,
            c.tipo_comprobante,
            c.serie,
            c.correlativo,
            c.fecha_emision,
            c.receptor_tipo_doc,
            c.receptor_num_doc,
            c.receptor_razon_social,
            per.direccion AS receptor_direccion,
            c.estado,
            c.estado_sunat,
            c.forma_envio,
            c.monto_igv,
            c.monto_total,
            c.hash_qr,
            c.ruta_xml,
            c.ruta_cdr,
            c.ruta_pdf_a4,
            c.fecha_limite_envio,
            c.codigo_respuesta_sunat,
            c.sunat_mensaje,
            c.observaciones_sunat,
            c.intentos_envio,
            c.fecha_envio_sunat,
            COALESCE((
                SELECT json_agg(json_build_object(
                    'id_producto', d.id_producto,
                    'descripcion', d.descripcion,
                    'cantidad', d.cantidad,
                    'unidad_sunat', d.unidad_sunat,
                    'tipo_afectacion_igv', d.tipo_afectacion_igv,
                    'tasa_igv', d.tasa_igv,
                    'valor_unitario', d.valor_unitario,
                    'precio_unitario_igv', d.precio_unitario_igv,
                    'monto_base_igv', d.monto_base_igv,
                    'monto_igv', d.monto_igv
                ) ORDER BY d.id)
                FROM ven_comprobante_detalle d
                WHERE d.id_comprobante = c.id
                  AND d.estado = 1
            ), '[]'::JSON) AS lineas
        FROM ven_comprobante c
        LEFT JOIN cli_persona per ON per.id = c.id_persona
        WHERE c.id = ANY(p_ids)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
