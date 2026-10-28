-- Crea un resumen diario (RC, p_tipo_lote 1) o una comunicación de baja (RA, 2) con
-- los comprobantes que aún califican:
--   estado_item 1 (adicionar): boletas pendientes del día; pasan a «en proceso» aquí
--                              mismo, así otro envío no las toma.
--   estado_item 3 (anular):    aceptados del día sin otra baja en curso o aceptada.
-- El correlativo es por tipo y día de envío (RC-AAAAMMDD-n). Devuelve registro NULL si
-- ninguno calificó.
-- p_items: [{ "id_comprobante": 1, "estado_item": 1, "motivo": "..." }]
DROP FUNCTION IF EXISTS ven_sunat_crear_lote(
    p_tipo_lote SMALLINT,
    p_fecha_documentos DATE,
    p_items JSONB,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION ven_sunat_crear_lote(
    p_tipo_lote SMALLINT,
    p_fecha_documentos DATE,
    p_items JSONB,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_adicionar BIGINT[];
    v_anular BIGINT[];
    v_tomados BIGINT[];
    v_fecha_envio DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'America/Lima')::DATE;
    v_correlativo INTEGER;
    v_identificador VARCHAR(30);
    v_id BIGINT;
BEGIN
    IF p_tipo_lote NOT IN (1, 2) THEN
        RETURN json_build_object('error', 'Tipo de lote inválido', 'registro', NULL);
    END IF;

    SELECT
        array_agg((i->>'id_comprobante')::BIGINT) FILTER (WHERE (i->>'estado_item')::SMALLINT = 1),
        array_agg((i->>'id_comprobante')::BIGINT) FILTER (WHERE (i->>'estado_item')::SMALLINT = 3)
    INTO v_adicionar, v_anular
    FROM jsonb_array_elements(COALESCE(p_items, '[]'::JSONB)) i;

    -- Boletas a adicionar (solo en resúmenes): se reservan de una vez.
    WITH reservados AS (
        UPDATE ven_comprobante c
        SET estado_sunat = 5,
            forma_envio = 2,
            intentos_envio = c.intentos_envio + 1,
            fecha_envio_sunat = CURRENT_TIMESTAMP
        WHERE p_tipo_lote = 1
          AND c.id = ANY(COALESCE(v_adicionar, '{}'))
          AND c.estado = 1
          AND c.tipo_comprobante = 1
          AND c.estado_sunat = 1
          AND (c.fecha_emision AT TIME ZONE 'America/Lima')::DATE = p_fecha_documentos
        RETURNING c.id
    )
    SELECT COALESCE(array_agg(id), '{}')
    INTO v_tomados
    FROM reservados;

    -- Comprobantes a anular: se bloquean y se descartan los que ya tienen baja.
    PERFORM 1
    FROM ven_comprobante c
    WHERE c.id = ANY(COALESCE(v_anular, '{}'))
    FOR UPDATE;

    v_tomados := v_tomados || COALESCE((
        SELECT array_agg(c.id)
        FROM ven_comprobante c
        WHERE c.id = ANY(COALESCE(v_anular, '{}'))
          AND c.estado_sunat = 2
          AND (c.fecha_emision AT TIME ZONE 'America/Lima')::DATE = p_fecha_documentos
          -- Boletas se anulan por resumen (RC) y facturas por comunicación de baja (RA).
          AND c.tipo_comprobante = CASE p_tipo_lote WHEN 1 THEN 1 ELSE 2 END
          AND NOT EXISTS (
              SELECT 1
              FROM ven_sunat_lote_detalle d
              INNER JOIN ven_sunat_lote l ON l.id = d.id_lote
              WHERE d.id_comprobante = c.id
                AND d.estado_item = 3
                AND l.estado = 1
                AND l.estado_sunat IN (1, 2, 5)
          )
    ), '{}');

    IF cardinality(v_tomados) = 0 THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    -- Serializa la asignación del correlativo del día para cada tipo de lote.
    PERFORM pg_advisory_xact_lock(908001, p_tipo_lote);

    SELECT COALESCE(MAX(l.correlativo), 0) + 1
    INTO v_correlativo
    FROM ven_sunat_lote l
    WHERE l.tipo_lote = p_tipo_lote
      AND l.fecha_envio = v_fecha_envio;

    v_identificador := CASE p_tipo_lote WHEN 1 THEN 'RC' ELSE 'RA' END
        || '-' || to_char(v_fecha_envio, 'YYYYMMDD') || '-' || v_correlativo;

    INSERT INTO ven_sunat_lote (
        tipo_lote,
        fecha_documentos,
        fecha_envio,
        correlativo,
        identificador,
        estado_sunat,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_tipo_lote,
        p_fecha_documentos,
        v_fecha_envio,
        v_correlativo,
        v_identificador,
        1,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    INSERT INTO ven_sunat_lote_detalle (id_lote, id_comprobante, estado_item, motivo)
    SELECT DISTINCT ON ((i->>'id_comprobante')::BIGINT)
        v_id,
        (i->>'id_comprobante')::BIGINT,
        (i->>'estado_item')::SMALLINT,
        LEFT(NULLIF(i->>'motivo', ''), 100)
    FROM jsonb_array_elements(p_items) i
    WHERE (i->>'id_comprobante')::BIGINT = ANY(v_tomados);

    RETURN json_build_object('registro', json_build_object(
        'id', v_id,
        'tipo_lote', p_tipo_lote,
        'correlativo', v_correlativo,
        'fecha_envio', v_fecha_envio,
        'fecha_documentos', p_fecha_documentos,
        'identificador', v_identificador,
        'items', (
            SELECT json_agg(json_build_object(
                'id_comprobante', d.id_comprobante,
                'estado_item', d.estado_item,
                'motivo', d.motivo
            ) ORDER BY d.id)
            FROM ven_sunat_lote_detalle d
            WHERE d.id_lote = v_id
        )
    ));
END;
$function$;
