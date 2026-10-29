-- Datos del emisor para los comprobantes electrónicos de una empresa: ubigeo de su
-- distrito y el token de APIsPERU (cifrado).
DROP FUNCTION IF EXISTS gen_obtener_emisor_sunat();
DROP FUNCTION IF EXISTS gen_obtener_emisor_sunat(p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION gen_obtener_emisor_sunat(p_id_empresa BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'ruc', e.ruc,
        'razon_social', e.razon_social,
        'nombre_comercial', e.nombre_comercial,
        'direccion', e.direccion,
        'ubigeo', d.codigo_ubigeo,
        'distrito', d.nombre,
        'provincia', p.nombre,
        'departamento', dp.nombre,
        'token_emision_cifrado', c.token_emision_cifrado,
        'id_ambiente', COALESCE(c.id_ambiente, 1)
    )
    INTO v_registro
    FROM gen_empresa e
    LEFT JOIN gen_distrito d ON d.id = e.id_distrito
    LEFT JOIN gen_provincia p ON p.id = d.id_provincia
    LEFT JOIN gen_departamento dp ON dp.id = p.id_departamento
    LEFT JOIN gen_configuracion_sunat c
        ON c.id_empresa = e.id
       AND c.estado = 1
    WHERE e.id = p_id_empresa
      AND e.estado = 1;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
