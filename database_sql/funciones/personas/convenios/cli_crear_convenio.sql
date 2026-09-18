-- Creo un convenio de crédito.
--
-- Pongo las validaciones acá y no solo en el DTO de Nest porque la base es la
-- última línea de defensa: si mañana alguien inserta desde otro lado (un script,
-- otro servicio), las reglas del negocio se siguen cumpliendo igual.
CREATE OR REPLACE FUNCTION cli_crear_convenio(
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_id_condicion_pago BIGINT,
    p_limite_credito NUMERIC DEFAULT 0,
    p_corte_quincenal BOOLEAN DEFAULT TRUE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_codigo VARCHAR;
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Normalizo el código a mayúsculas porque es el identificador que el
    -- usuario escribe a mano y no quiero "gvr" y "GVR" como dos convenios.
    v_codigo := UPPER(NULLIF(TRIM(p_codigo), ''));
    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_codigo IS NULL THEN
        RETURN json_build_object('error', 'El código del convenio es obligatorio', 'registro', NULL);
    END IF;

    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre del convenio es obligatorio', 'registro', NULL);
    END IF;

    -- Comparo contra TODOS los convenios, activos e inactivos, porque el
    -- UNIQUE de la tabla (uq_cli_convenio_codigo) tampoco distingue estado.
    -- Si solo mirara los activos, el INSERT reventaría con un error feo de
    -- Postgres en vez de este mensaje claro.
    IF EXISTS (SELECT 1 FROM cli_convenio WHERE codigo = v_codigo) THEN
        RETURN json_build_object('error', 'Ya existe un convenio con el código ' || v_codigo, 'registro', NULL);
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
        codigo,
        nombre,
        id_condicion_pago,
        limite_credito,
        corte_quincenal,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_codigo,
        v_nombre,
        p_id_condicion_pago,
        COALESCE(p_limite_credito, 0),
        COALESCE(p_corte_quincenal, TRUE),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cli_obtener_convenio(v_id);
END;
$function$;
