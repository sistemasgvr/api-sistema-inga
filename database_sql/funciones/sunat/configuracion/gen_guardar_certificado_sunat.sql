-- Guarda el certificado digital (PEM cifrado en el API) con su titular y vencimiento.
-- p_datos: certificado_cifrado, clave_certificado_cifrada, certificado_titular, certificado_vence.
DROP FUNCTION IF EXISTS gen_guardar_certificado_sunat(
    p_id_empresa BIGINT,
    p_datos JSONB,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gen_guardar_certificado_sunat(
    p_id_empresa BIGINT,
    p_datos JSONB,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM gen_empresa WHERE id = p_id_empresa AND estado = 1) THEN
        RETURN json_build_object('error', 'La empresa no existe o está inactiva', 'registro', NULL);
    END IF;

    IF NULLIF(p_datos->>'certificado_cifrado', '') IS NULL THEN
        RETURN json_build_object('error', 'El certificado es obligatorio', 'registro', NULL);
    END IF;

    INSERT INTO gen_configuracion_sunat (
        id_empresa,
        proveedor_ose,
        certificado_cifrado,
        clave_certificado_cifrada,
        certificado_titular,
        certificado_vence,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_empresa,
        'APISPERU',
        p_datos->>'certificado_cifrado',
        p_datos->>'clave_certificado_cifrada',
        NULLIF(p_datos->>'certificado_titular', ''),
        (p_datos->>'certificado_vence')::TIMESTAMPTZ,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    ON CONFLICT ON CONSTRAINT uq_gen_config_sunat_empresa DO UPDATE SET
        certificado_cifrado = EXCLUDED.certificado_cifrado,
        clave_certificado_cifrada = EXCLUDED.clave_certificado_cifrada,
        certificado_titular = EXCLUDED.certificado_titular,
        certificado_vence = EXCLUDED.certificado_vence,
        estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = CURRENT_TIMESTAMP;

    RETURN gen_obtener_configuracion_sunat();
END;
$function$;
