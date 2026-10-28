-- Boletas y facturas pendientes cuya fecha límite de envío ya llegó (las toma el
-- programador). Se saltan las que fallaron hace menos de 15 minutos.
DROP FUNCTION IF EXISTS ven_sunat_listar_vencidos(p_limite INTEGER);
CREATE OR REPLACE FUNCTION ven_sunat_listar_vencidos(p_limite INTEGER DEFAULT 200)
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
            c.tipo_comprobante,
            (c.fecha_emision AT TIME ZONE 'America/Lima')::DATE AS dia
        FROM ven_comprobante c
        WHERE c.estado = 1
          AND c.tipo_comprobante IN (1, 2)
          AND c.estado_sunat = 1
          AND c.fecha_limite_envio <= (CURRENT_TIMESTAMP AT TIME ZONE 'America/Lima')::DATE
          AND (
              c.fecha_envio_sunat IS NULL
              OR c.fecha_envio_sunat < CURRENT_TIMESTAMP - INTERVAL '15 minutes'
          )
        ORDER BY c.fecha_limite_envio, c.id
        LIMIT p_limite
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
