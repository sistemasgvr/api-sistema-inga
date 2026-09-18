-- Valida los datos de una persona y devuelve el mensaje de error, o NULL si todo está bien.
--
-- La saqué a una función aparte porque crear y actualizar necesitan exactamente
-- las mismas reglas. Si las dejaba copiadas en las dos, tarde o temprano alguien
-- iba a corregir una y olvidarse de la otra.
--
-- Devuelve TEXT (no JSON) para que quien la llame arme la respuesta como le
-- convenga; así también sirve el día que la necesite una carga masiva.
--
-- Las reglas salen de los requerimientos:
--   M07 → un proveedor se elige por es_proveedor = TRUE
--   M12 → cobrar a crédito exige es_cliente = TRUE y un convenio activo
--   M13 → para factura el receptor debe tener RUC de 11 dígitos y ser jurídica
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
    p_id_distrito BIGINT
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

    -- 1 = DNI, 4 = CE, 6 = RUC (catálogo DOCUMENTO_TIPO, códigos SUNAT)
    IF p_tipo_documento NOT IN (1, 4, 6) THEN
        RETURN 'El tipo de documento debe ser DNI, RUC o carné de extranjería';
    END IF;

    IF v_doc IS NULL THEN
        RETURN 'El número de documento es obligatorio';
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

    -- Una empresa siempre va con RUC y razón social. Esto es lo que después
    -- permite emitir factura (M13) sin tener que pedir los datos de nuevo.
    IF p_tipo_persona = 2 THEN
        IF p_tipo_documento <> 6 THEN
            RETURN 'Una persona jurídica debe identificarse con RUC';
        END IF;
        IF NULLIF(TRIM(p_razon_social), '') IS NULL THEN
            RETURN 'La razón social es obligatoria para una persona jurídica';
        END IF;
    END IF;

    -- Una persona natural necesita al menos nombre y apellido paterno, porque
    -- con eso armo el "nombre_completo" que se muestra en todos los buscadores.
    IF p_tipo_persona = 1 THEN
        IF NULLIF(TRIM(p_nombres), '') IS NULL THEN
            RETURN 'Los nombres son obligatorios para una persona natural';
        END IF;
        IF NULLIF(TRIM(p_apellido_paterno), '') IS NULL THEN
            RETURN 'El apellido paterno es obligatorio para una persona natural';
        END IF;
    END IF;

    -- Sin al menos un rol la ficha no sirve para nada: no aparecería ni en el
    -- buscador de compras ni en el de cobro a crédito.
    IF COALESCE(p_es_cliente, FALSE) = FALSE AND COALESCE(p_es_proveedor, FALSE) = FALSE THEN
        RETURN 'Marca al menos un rol: cliente, proveedor o ambos';
    END IF;

    -- El convenio es crédito de consumo, así que solo tiene sentido en clientes.
    IF p_id_convenio IS NOT NULL AND COALESCE(p_es_cliente, FALSE) = FALSE THEN
        RETURN 'Solo un cliente puede tener convenio de crédito asignado';
    END IF;

    IF p_id_convenio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_convenio WHERE id = p_id_convenio AND estado = 1
    ) THEN
        RETURN 'El convenio indicado no existe o está inactivo';
    END IF;

    IF p_id_distrito IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_distrito WHERE id = p_id_distrito
    ) THEN
        RETURN 'El distrito indicado no existe';
    END IF;

    -- Validación de correo a propósito simple: solo descarto lo evidentemente
    -- mal escrito. Una expresión estricta rechaza correos válidos raros y da
    -- más problemas de los que resuelve.
    IF NULLIF(TRIM(p_email), '') IS NOT NULL AND TRIM(p_email) !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
        RETURN 'El correo electrónico no tiene un formato válido';
    END IF;

    RETURN NULL;
END;
$function$;
