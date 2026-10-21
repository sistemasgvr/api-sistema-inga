-- Actualizo un convenio. Lo que llega en NULL se queda como está.
DROP FUNCTION IF EXISTS cli_actualizar_convenio(
    p_id BIGINT,
    p_nombre VARCHAR,
    p_id_condicion_pago BIGINT,
    p_limite_credito NUMERIC,
    p_corte_quincenal BOOLEAN,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION cli_actualizar_convenio(
    p_id BIGINT,
    p_nombre VARCHAR DEFAULT NULL,
    p_id_condicion_pago BIGINT DEFAULT NULL,
    p_limite_credito NUMERIC DEFAULT NULL,
    p_corte_quincenal BOOLEAN DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF NOT EXISTS (SELECT 1 FROM cli_convenio WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El convenio no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_condicion_pago IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_condicion_pago WHERE id = p_id_condicion_pago AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La condición de pago indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_limite_credito IS NOT NULL AND p_limite_credito < 0 THEN
        RETURN json_build_object('error', 'El límite de crédito no puede ser negativo', 'registro', NULL);
    END IF;

    UPDATE cli_convenio
    SET
        nombre = COALESCE(v_nombre, nombre),
        id_condicion_pago = COALESCE(p_id_condicion_pago, id_condicion_pago),
        limite_credito = COALESCE(p_limite_credito, limite_credito),
        corte_quincenal = COALESCE(p_corte_quincenal, corte_quincenal),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN cli_obtener_convenio(p_id);
END;
$function$;
