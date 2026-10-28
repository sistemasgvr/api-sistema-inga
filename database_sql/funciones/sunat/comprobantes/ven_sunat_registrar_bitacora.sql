-- Bitácora de llamadas a APIsPERU (sin archivos en base64).
-- p_datos: id_comprobante, id_lote, operacion, exito, codigo, mensaje, respuesta, id_usuario.
DROP FUNCTION IF EXISTS ven_sunat_registrar_bitacora(p_datos JSONB);
CREATE OR REPLACE FUNCTION ven_sunat_registrar_bitacora(p_datos JSONB)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO ven_comprobante_sunat_log (
        id_comprobante,
        id_lote,
        operacion,
        exito,
        codigo,
        mensaje,
        respuesta,
        id_usuario
    )
    VALUES (
        (p_datos->>'id_comprobante')::BIGINT,
        (p_datos->>'id_lote')::BIGINT,
        p_datos->>'operacion',
        COALESCE((p_datos->>'exito')::BOOLEAN, FALSE),
        LEFT(p_datos->>'codigo', 20),
        LEFT(p_datos->>'mensaje', 4000),
        p_datos->'respuesta',
        (p_datos->>'id_usuario')::BIGINT
    )
    RETURNING id INTO v_id;

    RETURN json_build_object('id', v_id);
END;
$function$;
