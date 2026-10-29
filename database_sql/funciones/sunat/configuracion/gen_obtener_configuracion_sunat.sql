-- Configuración SUNAT/APIsPERU de una empresa (la de la sesión).
-- Devuelve los valores cifrados: el API decide qué mostrar y nunca los entrega al front.
DROP FUNCTION IF EXISTS gen_obtener_configuracion_sunat();
DROP FUNCTION IF EXISTS gen_obtener_configuracion_sunat(p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION gen_obtener_configuracion_sunat(p_id_empresa BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'id_empresa', e.id,
        'id', c.id,
        'proveedor_ose', c.proveedor_ose,
        'token_emision_cifrado', c.token_emision_cifrado,
        'usuario_sol_cifrado', c.usuario_sol_cifrado,
        'clave_sol_cifrada', c.clave_sol_cifrada,
        'certificado_cifrado', c.certificado_cifrado,
        'clave_certificado_cifrada', c.clave_certificado_cifrada,
        'certificado_titular', c.certificado_titular,
        'certificado_vence', c.certificado_vence,
        'id_ambiente', c.id_ambiente,
        'dias_limite_envio_boleta', c.dias_limite_envio_boleta,
        'dias_limite_envio_factura', c.dias_limite_envio_factura,
        'fecha_modificacion', c.fecha_modificacion
    )
    INTO v_registro
    FROM gen_empresa e
    LEFT JOIN gen_configuracion_sunat c
        ON c.id_empresa = e.id
       AND c.estado = 1
    WHERE e.id = p_id_empresa
      AND e.estado = 1;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
