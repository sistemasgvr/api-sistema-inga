-- Datos de una empresa concreta (la de la sesión). La configuración SUNAT cuelga
-- de esta misma fila.
DROP FUNCTION IF EXISTS gen_obtener_empresa();
DROP FUNCTION IF EXISTS gen_obtener_empresa(p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION gen_obtener_empresa(p_id_empresa BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'id', e.id,
        'ruc', e.ruc,
        'razon_social', e.razon_social,
        'nombre_comercial', e.nombre_comercial,
        'direccion', e.direccion,
        'id_distrito', e.id_distrito,
        'tasa_igv', e.tasa_igv,
        'logo_url', e.logo_url,
        'logo_ticket', e.logo_ticket
    )
    INTO v_registro
    FROM gen_empresa e
    WHERE e.id = p_id_empresa
      AND e.estado = 1;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
