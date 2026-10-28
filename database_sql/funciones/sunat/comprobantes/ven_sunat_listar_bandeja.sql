-- Bandeja SUNAT: por defecto pendientes, en proceso y rechazados; o el estado indicado.
-- Ordenada por fecha límite para atender primero lo que vence.
DROP FUNCTION IF EXISTS ven_sunat_listar_bandeja(
    p_estado_sunat SMALLINT,
    p_tipo_comprobante SMALLINT,
    p_limite INTEGER,
    p_offset INTEGER
);
CREATE OR REPLACE FUNCTION ven_sunat_listar_bandeja(
    p_estado_sunat SMALLINT DEFAULT NULL,
    p_tipo_comprobante SMALLINT DEFAULT NULL,
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_hoy DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'America/Lima')::DATE;
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM ven_comprobante c
    WHERE c.tipo_comprobante IN (1, 2)
      AND (p_tipo_comprobante IS NULL OR c.tipo_comprobante = p_tipo_comprobante)
      AND (
          (p_estado_sunat IS NULL AND c.estado_sunat IN (1, 3, 5))
          OR c.estado_sunat = p_estado_sunat
      );

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
            c.sunat_mensaje,
            c.codigo_respuesta_sunat,
            c.fecha_emision,
            c.fecha_limite_envio,
            c.fecha_envio_sunat,
            c.intentos_envio,
            (c.estado_sunat = 1 AND c.fecha_limite_envio <= v_hoy + 1) AS por_vencer
        FROM ven_comprobante c
        WHERE c.tipo_comprobante IN (1, 2)
          AND (p_tipo_comprobante IS NULL OR c.tipo_comprobante = p_tipo_comprobante)
          AND (
              (p_estado_sunat IS NULL AND c.estado_sunat IN (1, 3, 5))
              OR c.estado_sunat = p_estado_sunat
          )
        ORDER BY c.fecha_limite_envio NULLS LAST, c.id
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total
    );
END;
$function$;
