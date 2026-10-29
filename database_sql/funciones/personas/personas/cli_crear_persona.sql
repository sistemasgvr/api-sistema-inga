DROP FUNCTION IF EXISTS cli_crear_persona(
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
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION cli_crear_persona(
    p_tipo_persona SMALLINT,
    p_tipo_documento SMALLINT,
    p_num_documento VARCHAR,
    p_razon_social VARCHAR DEFAULT NULL,
    p_nombres VARCHAR DEFAULT NULL,
    p_apellido_paterno VARCHAR DEFAULT NULL,
    p_apellido_materno VARCHAR DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_id_distrito BIGINT DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_es_cliente BOOLEAN DEFAULT FALSE,
    p_es_proveedor BOOLEAN DEFAULT FALSE,
    p_id_convenio BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_doc VARCHAR;
    v_error TEXT;
    v_existente RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_doc := NULLIF(TRIM(p_num_documento), '');

    v_error := cli_validar_datos_persona(
        p_tipo_persona, p_tipo_documento, v_doc, p_razon_social,
        p_nombres, p_apellido_paterno, p_email,
        p_es_cliente, p_es_proveedor, p_id_convenio, p_id_distrito,
        p_id_empresa
    );

    IF v_error IS NOT NULL THEN
        RETURN json_build_object('error', v_error, 'registro', NULL);
    END IF;

    SELECT id, estado INTO v_existente
    FROM cli_persona
    WHERE v_doc IS NOT NULL AND tipo_documento = p_tipo_documento AND num_documento = v_doc
      AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa);

    IF FOUND THEN
        IF v_existente.estado = 0 THEN
            RETURN json_build_object(
                'error', 'Ya existe una persona dada de baja con el documento ' || v_doc ||
                         '. Reactívala desde el filtro de inactivos en lugar de crearla de nuevo.',
                'registro', NULL
            );
        END IF;
        RETURN json_build_object(
            'error', 'Ya existe una persona registrada con el documento ' || v_doc,
            'registro', NULL
        );
    END IF;

    INSERT INTO cli_persona (
        id_empresa,
        tipo_persona,
        tipo_documento,
        num_documento,
        razon_social,
        nombres,
        apellido_paterno,
        apellido_materno,
        direccion,
        id_distrito,
        telefono,
        email,
        es_cliente,
        es_proveedor,
        id_convenio,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_empresa,
        p_tipo_persona,
        CASE WHEN v_doc IS NULL THEN NULL ELSE p_tipo_documento END,
        v_doc,
        NULLIF(TRIM(p_razon_social), ''),
        NULLIF(TRIM(p_nombres), ''),
        NULLIF(TRIM(p_apellido_paterno), ''),
        NULLIF(TRIM(p_apellido_materno), ''),
        NULLIF(TRIM(p_direccion), ''),
        p_id_distrito,
        NULLIF(TRIM(p_telefono), ''),
        LOWER(NULLIF(TRIM(p_email), '')),
        COALESCE(p_es_cliente, FALSE),
        COALESCE(p_es_proveedor, FALSE),
        p_id_convenio,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cli_obtener_persona(v_id, p_id_empresa);
END;
$function$;