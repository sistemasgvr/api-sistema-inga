-- Resúmenes diarios (RC) y comunicaciones de baja (RA), del más reciente al más antiguo.
DROP FUNCTION IF EXISTS ven_sunat_listar_lotes(
    p_fecha DATE,
    p_tipo_lote SMALLINT,
    p_limite INTEGER,
    p_offset INTEGER
);
CREATE OR REPLACE FUNCTION ven_sunat_listar_lotes(
    p_fecha DATE DEFAULT NULL,
    p_tipo_lote SMALLINT DEFAULT NULL,
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM ven_sunat_lote l
    WHERE l.estado = 1
      AND (p_fecha IS NULL OR l.fecha_documentos = p_fecha OR l.fecha_envio = p_fecha)
      AND (p_tipo_lote IS NULL OR l.tipo_lote = p_tipo_lote);

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            l.id,
            l.tipo_lote,
            l.identificador,
            l.fecha_documentos,
            l.fecha_envio,
            l.ticket,
            l.estado_sunat,
            l.codigo_respuesta_sunat,
            l.sunat_mensaje,
            l.intentos_consulta,
            l.ruta_xml IS NOT NULL AS tiene_xml,
            l.ruta_cdr IS NOT NULL AS tiene_cdr,
            l.fecha_creacion,
            (
                SELECT COUNT(*)
                FROM ven_sunat_lote_detalle d
                WHERE d.id_lote = l.id
            ) AS cantidad
        FROM ven_sunat_lote l
        WHERE l.estado = 1
          AND (p_fecha IS NULL OR l.fecha_documentos = p_fecha OR l.fecha_envio = p_fecha)
          AND (p_tipo_lote IS NULL OR l.tipo_lote = p_tipo_lote)
        ORDER BY l.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total
    );
END;
$function$;
