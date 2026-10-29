-- Pendientes que vencen hoy o mañana, por tipo de comprobante (aviso diario).
DROP FUNCTION IF EXISTS ven_sunat_resumen_por_vencer();
DROP FUNCTION IF EXISTS ven_sunat_resumen_por_vencer(p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_resumen_por_vencer(p_id_empresa BIGINT DEFAULT NULL)
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
            c.tipo_comprobante,
            COUNT(*) AS cantidad,
            MIN(c.fecha_limite_envio) AS vence
        FROM ven_comprobante c
        WHERE c.estado = 1
          AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
          AND c.tipo_comprobante IN (1, 2)
          AND c.estado_sunat = 1
          AND c.fecha_limite_envio <= (CURRENT_TIMESTAMP AT TIME ZONE 'America/Lima')::DATE + 1
        GROUP BY c.tipo_comprobante
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
