-- Crea o actualiza la configuración SUNAT de la empresa. Los campos que no llegan
-- (NULL) conservan su valor: así el front no tiene que reenviar los secretos.
-- p_datos: token_emision_cifrado, usuario_sol_cifrado, clave_sol_cifrada, id_ambiente,
--          dias_limite_envio_boleta, dias_limite_envio_factura.
DROP FUNCTION IF EXISTS gen_guardar_configuracion_sunat(
    p_id_empresa BIGINT,
    p_datos JSONB,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gen_guardar_configuracion_sunat(
    p_id_empresa BIGINT,
    p_datos JSONB,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_token TEXT := NULLIF(p_datos->>'token_emision_cifrado', '');
    v_usuario_sol TEXT := NULLIF(p_datos->>'usuario_sol_cifrado', '');
    v_clave_sol TEXT := NULLIF(p_datos->>'clave_sol_cifrada', '');
    v_ambiente SMALLINT := (p_datos->>'id_ambiente')::SMALLINT;
    v_dias_boleta SMALLINT := (p_datos->>'dias_limite_envio_boleta')::SMALLINT;
    v_dias_factura SMALLINT := (p_datos->>'dias_limite_envio_factura')::SMALLINT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM gen_empresa WHERE id = p_id_empresa AND estado = 1) THEN
        RETURN json_build_object('error', 'La empresa no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_ambiente IS NOT NULL AND v_ambiente NOT IN (1, 2) THEN
        RETURN json_build_object('error', 'Seleccione el ambiente Beta o Producción', 'registro', NULL);
    END IF;

    INSERT INTO gen_configuracion_sunat (
        id_empresa,
        proveedor_ose,
        token_emision_cifrado,
        usuario_sol_cifrado,
        clave_sol_cifrada,
        id_ambiente,
        dias_limite_envio_boleta,
        dias_limite_envio_factura,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_empresa,
        'APISPERU',
        v_token,
        v_usuario_sol,
        v_clave_sol,
        COALESCE(v_ambiente, 1),
        COALESCE(v_dias_boleta, 3),
        COALESCE(v_dias_factura, 7),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    ON CONFLICT ON CONSTRAINT uq_gen_config_sunat_empresa DO UPDATE SET
        proveedor_ose = 'APISPERU',
        token_emision_cifrado = COALESCE(v_token, gen_configuracion_sunat.token_emision_cifrado),
        usuario_sol_cifrado = COALESCE(v_usuario_sol, gen_configuracion_sunat.usuario_sol_cifrado),
        clave_sol_cifrada = COALESCE(v_clave_sol, gen_configuracion_sunat.clave_sol_cifrada),
        id_ambiente = COALESCE(v_ambiente, gen_configuracion_sunat.id_ambiente),
        dias_limite_envio_boleta = COALESCE(v_dias_boleta, gen_configuracion_sunat.dias_limite_envio_boleta),
        dias_limite_envio_factura = COALESCE(v_dias_factura, gen_configuracion_sunat.dias_limite_envio_factura),
        estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = CURRENT_TIMESTAMP;

    RETURN gen_obtener_configuracion_sunat();
END;
$function$;
