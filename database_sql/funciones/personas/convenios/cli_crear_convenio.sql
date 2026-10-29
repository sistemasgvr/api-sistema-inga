DROP FUNCTION IF EXISTS cli_crear_convenio(
    p_nombre VARCHAR,
    p_id_condicion_pago BIGINT,
    p_limite_credito NUMERIC,
    p_corte_quincenal BOOLEAN,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION cli_crear_convenio(
    p_nombre VARCHAR,
    p_id_condicion_pago BIGINT,
    p_limite_credito NUMERIC DEFAULT 0,
    p_corte_quincenal BOOLEAN DEFAULT TRUE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');


    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre del convenio es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_condicion_pago WHERE id = p_id_condicion_pago AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La condición de pago indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF COALESCE(p_limite_credito, 0) < 0 THEN
        RETURN json_build_object('error', 'El límite de crédito no puede ser negativo', 'registro', NULL);
    END IF;

    INSERT INTO cli_convenio (
        id_empresa,
        nombre,
        id_condicion_pago,
        limite_credito,
        corte_quincenal,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_empresa,
        v_nombre,
        p_id_condicion_pago,
        COALESCE(p_limite_credito, 0),
        COALESCE(p_corte_quincenal, TRUE),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cli_obtener_convenio(v_id, p_id_empresa);
END;
$function$;