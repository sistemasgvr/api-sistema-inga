-- Actualizo una persona (NULL = sin cambio). Se valida la mezcla de lo que llega con lo guardado,
-- no solo los campos enviados, para no dejar la ficha en un estado imposible.
DROP FUNCTION IF EXISTS cli_actualizar_persona(
    p_id BIGINT,
    p_tipo_persona SMALLINT,
    p_tipo_documento SMALLINT,
    p_num_documento VARCHAR,
    p_razon_social VARCHAR,
    p_nombres VARCHAR,
    p_apellido_paterno VARCHAR,
    p_apellido_materno VARCHAR,
    p_direccion VARCHAR,
    p_id_distrito BIGINT,
    p_telefono VARCHAR,
    p_email VARCHAR,
    p_es_cliente BOOLEAN,
    p_es_proveedor BOOLEAN,
    p_id_convenio BIGINT,
    p_quitar_convenio BOOLEAN,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION cli_actualizar_persona(
    p_id BIGINT,
    p_tipo_persona SMALLINT DEFAULT NULL,
    p_tipo_documento SMALLINT DEFAULT NULL,
    p_num_documento VARCHAR DEFAULT NULL,
    p_razon_social VARCHAR DEFAULT NULL,
    p_nombres VARCHAR DEFAULT NULL,
    p_apellido_paterno VARCHAR DEFAULT NULL,
    p_apellido_materno VARCHAR DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_id_distrito BIGINT DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_es_cliente BOOLEAN DEFAULT NULL,
    p_es_proveedor BOOLEAN DEFAULT NULL,
    p_id_convenio BIGINT DEFAULT NULL,
    -- Bandera para quitar el convenio: NULL en p_id_convenio solo significa "sin cambio".
    p_quitar_convenio BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_actual RECORD;
    v_error TEXT;
    v_tipo_persona SMALLINT;
    v_tipo_documento SMALLINT;
    v_num_documento VARCHAR;
    v_razon_social VARCHAR;
    v_nombres VARCHAR;
    v_apellido_paterno VARCHAR;
    v_es_cliente BOOLEAN;
    v_es_proveedor BOOLEAN;
    v_id_convenio BIGINT;
    v_id_distrito BIGINT;
    v_email VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_actual FROM cli_persona WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La persona no existe o está inactiva', 'registro', NULL);
    END IF;

    v_tipo_persona     := COALESCE(p_tipo_persona, v_actual.tipo_persona);
    v_tipo_documento   := COALESCE(p_tipo_documento, v_actual.tipo_documento);
    v_num_documento    := COALESCE(NULLIF(TRIM(p_num_documento), ''), v_actual.num_documento);
    v_razon_social     := COALESCE(NULLIF(TRIM(p_razon_social), ''), v_actual.razon_social);
    v_nombres          := COALESCE(NULLIF(TRIM(p_nombres), ''), v_actual.nombres);
    v_apellido_paterno := COALESCE(NULLIF(TRIM(p_apellido_paterno), ''), v_actual.apellido_paterno);
    v_es_cliente       := COALESCE(p_es_cliente, v_actual.es_cliente);
    v_es_proveedor     := COALESCE(p_es_proveedor, v_actual.es_proveedor);
    v_id_distrito      := COALESCE(p_id_distrito, v_actual.id_distrito);
    v_email            := COALESCE(NULLIF(TRIM(p_email), ''), v_actual.email);

    IF p_quitar_convenio THEN
        v_id_convenio := NULL;
    ELSE
        v_id_convenio := COALESCE(p_id_convenio, v_actual.id_convenio);
    END IF;

    v_error := cli_validar_datos_persona(
        v_tipo_persona, v_tipo_documento, v_num_documento, v_razon_social,
        v_nombres, v_apellido_paterno, v_email,
        v_es_cliente, v_es_proveedor, v_id_convenio, v_id_distrito
    );

    IF v_error IS NOT NULL THEN
        RETURN json_build_object('error', v_error, 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM cli_persona
        WHERE tipo_documento = v_tipo_documento
          AND num_documento = v_num_documento
          AND id <> p_id
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe otra persona registrada con el documento ' || v_num_documento,
            'registro', NULL
        );
    END IF;

    UPDATE cli_persona
    SET
        tipo_persona = v_tipo_persona,
        tipo_documento = v_tipo_documento,
        num_documento = v_num_documento,
        razon_social = v_razon_social,
        nombres = v_nombres,
        apellido_paterno = v_apellido_paterno,
        -- Apellido materno y dirección sí pueden quedar vacíos: se usa el valor tal cual llega.
        apellido_materno = COALESCE(NULLIF(TRIM(p_apellido_materno), ''), apellido_materno),
        direccion = COALESCE(NULLIF(TRIM(p_direccion), ''), direccion),
        id_distrito = v_id_distrito,
        telefono = COALESCE(NULLIF(TRIM(p_telefono), ''), telefono),
        email = LOWER(v_email),
        es_cliente = v_es_cliente,
        es_proveedor = v_es_proveedor,
        id_convenio = v_id_convenio,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN cli_obtener_persona(p_id);
END;
$function$;
