-- Boletas y facturas emitidas en un día de Lima (resumen del día y envío masivo).
DROP FUNCTION IF EXISTS ven_sunat_listar_comprobantes_dia(p_fecha DATE);
DROP FUNCTION IF EXISTS ven_sunat_listar_comprobantes_dia(p_fecha DATE, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_listar_comprobantes_dia(
    p_fecha DATE,
    p_id_empresa BIGINT DEFAULT NULL
)
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
            c.id,
            c.id_pedido,
            c.tipo_comprobante,
            c.serie || '-' || c.correlativo AS numero,
            c.receptor_num_doc,
            c.receptor_razon_social,
            c.monto_total,
            c.estado,
            c.estado_sunat,
            c.forma_envio,
            c.sunat_mensaje,
            c.fecha_limite_envio,
            c.fecha_emision
        FROM ven_comprobante c
        WHERE c.tipo_comprobante IN (1, 2)
          AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
          AND (c.fecha_emision AT TIME ZONE 'America/Lima')::DATE = p_fecha
        ORDER BY c.tipo_comprobante, c.serie, c.correlativo
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
