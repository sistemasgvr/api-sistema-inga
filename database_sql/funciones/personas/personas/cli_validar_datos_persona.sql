DROP FUNCTION IF EXISTS cli_validar_datos_persona(
    p_tipo_persona SMALLINT,
    p_tipo_documento SMALLINT,
    p_num_documento VARCHAR,
    p_razon_social VARCHAR,
    p_nombres VARCHAR,
    p_apellido_paterno VARCHAR,
    p_email VARCHAR,
    p_es_cliente BOOLEAN,
    p_es_proveedor BOOLEAN,
    p_id_convenio BIGINT,
    p_id_distrito BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION cli_validar_datos_persona(
    p_tipo_persona SMALLINT,
    p_tipo_documento SMALLINT,
    p_num_documento VARCHAR,
    p_razon_social VARCHAR,
    p_nombres VARCHAR,
    p_apellido_paterno VARCHAR,
    p_email VARCHAR,
    p_es_cliente BOOLEAN,
    p_es_proveedor BOOLEAN,
    p_id_convenio BIGINT,
    p_id_distrito BIGINT,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc VARCHAR;
BEGIN
    v_doc := NULLIF(TRIM(p_num_documento), '');

    -- 1 = natural, 2 = jurídica (catálogo PERSONA_TIPO)
    IF p_tipo_persona NOT IN (1, 2) THEN
        RETURN 'El tipo de persona debe ser natural o jurídica';
    END IF;

    -- El documento es opcional; si se envía, debe venir con su tipo y cumplir el formato.
    -- 1 = DNI, 4 = CE, 6 = RUC (catálogo DOCUMENTO_TIPO, códigos SUNAT)
    IF v_doc IS NOT NULL AND (p_tipo_documento IS NULL OR p_tipo_documento NOT IN (1, 4, 6, 7)) THEN
        RETURN 'El tipo de documento debe ser DNI, RUC, carné de extranjería o pasaporte';
    END IF;

    IF p_tipo_documento = 1 AND v_doc !~ '^[0-9]{8}$' THEN
        RETURN 'El DNI debe tener exactamente 8 dígitos numéricos';
    END IF;

    IF p_tipo_documento = 6 AND v_doc !~ '^[0-9]{11}$' THEN
        RETURN 'El RUC debe tener exactamente 11 dígitos numéricos';
    END IF;

    IF p_tipo_documento = 4 AND v_doc !~ '^[A-Za-z0-9]{8,12}$' THEN
        RETURN 'El carné de extranjería debe tener entre 8 y 12 caracteres alfanuméricos';
    END IF;

    IF p_tipo_documento = 7 AND v_doc !~ '^[A-Za-z0-9]{1,20}$' THEN
        RETURN 'El pasaporte debe tener entre 1 y 20 caracteres alfanuméricos';
    END IF;

    IF p_tipo_persona = 2 THEN
        IF v_doc IS NULL OR p_tipo_documento IS DISTINCT FROM 6 THEN
            RETURN 'Una persona jurídica debe identificarse con RUC';
        END IF;
        IF NULLIF(TRIM(p_razon_social), '') IS NULL THEN
            RETURN 'La razón social es obligatoria para una persona jurídica';
        END IF;
    END IF;

    IF p_tipo_persona = 1 THEN
        IF NULLIF(TRIM(p_nombres), '') IS NULL THEN
            RETURN 'Los nombres son obligatorios para una persona natural';
        END IF;
        IF NULLIF(TRIM(p_apellido_paterno), '') IS NULL THEN
            RETURN 'El apellido paterno es obligatorio para una persona natural';
        END IF;
    END IF;

    IF COALESCE(p_es_cliente, FALSE) = FALSE AND COALESCE(p_es_proveedor, FALSE) = FALSE THEN
        RETURN 'Marca al menos un rol: cliente, proveedor o ambos';
    END IF;

    IF p_id_convenio IS NOT NULL AND COALESCE(p_es_cliente, FALSE) = FALSE THEN
        RETURN 'Solo un cliente puede tener convenio de crédito asignado';
    END IF;

    IF p_id_convenio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_convenio WHERE id = p_id_convenio AND estado = 1
          AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa)
    ) THEN
        RETURN 'El convenio indicado no existe o está inactivo';
    END IF;

    IF p_id_distrito IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_distrito WHERE id = p_id_distrito
    ) THEN
        RETURN 'El distrito indicado no existe';
    END IF;

    -- Validación de correo simple a propósito: una estricta rechaza correos válidos.
    IF NULLIF(TRIM(p_email), '') IS NOT NULL AND TRIM(p_email) !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
        RETURN 'El correo electrónico no tiene un formato válido';
    END IF;

    RETURN NULL;
END;
$function$;
