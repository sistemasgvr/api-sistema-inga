-- Comprobante vigente de un pedido y su estado SUNAT: al reemitir, si ya estaba
-- aceptado, el API envía su baja.
DROP FUNCTION IF EXISTS ven_sunat_comprobante_vigente(p_id_pedido BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_comprobante_vigente(p_id_pedido BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'id', c.id,
        'estado_sunat', c.estado_sunat,
        'tipo_comprobante', c.tipo_comprobante
    )
    INTO v_registro
    FROM ven_comprobante c
    WHERE c.id_pedido = p_id_pedido
      AND c.estado = 1
    ORDER BY c.id DESC
    LIMIT 1;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
