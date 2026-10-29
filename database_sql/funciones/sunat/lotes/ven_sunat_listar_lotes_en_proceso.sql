-- Lotes con ticket cuya respuesta falta. Sin p_id_lote devuelve los que no se
-- consultaron en los últimos 2 minutos; con p_id_lote, solo ese.
DROP FUNCTION IF EXISTS ven_sunat_listar_lotes_en_proceso(p_id_lote BIGINT);
DROP FUNCTION IF EXISTS ven_sunat_listar_lotes_en_proceso(p_id_lote BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_listar_lotes_en_proceso(
    p_id_lote BIGINT DEFAULT NULL,
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
            l.id,
            l.id_empresa,
            l.tipo_lote,
            l.ticket,
            l.identificador,
            l.intentos_consulta
        FROM ven_sunat_lote l
        WHERE l.estado = 1
          AND (p_id_empresa IS NULL OR l.id_empresa = p_id_empresa)
          AND l.estado_sunat = 5
          AND l.ticket IS NOT NULL
          AND (
              (p_id_lote IS NOT NULL AND l.id = p_id_lote)
              OR (
                  p_id_lote IS NULL
                  AND (
                      l.fecha_consulta IS NULL
                      OR l.fecha_consulta < CURRENT_TIMESTAMP - INTERVAL '2 minutes'
                  )
              )
          )
        ORDER BY l.id
        LIMIT 50
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
