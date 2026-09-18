-- Actualizo una persona.
--
-- Detalle importante: primero leo la fila actual y mezclo cada parámetro con lo
-- que ya estaba guardado, y RECIÉN AHÍ valido. Si validara solo lo que llega,
-- podría dejar la ficha en un estado imposible. Ejemplo real: la persona es
-- jurídica y me mandan solo razon_social = '' para "limpiarla"; validando solo
-- ese campo no vería el problema, pero el resultado final sería una empresa sin
-- razón social. Validando la mezcla, lo detecto.
--
-- Uso NULL como "no me mandaron este campo", así el front puede enviar
-- únicamente lo que el usuario tocó.
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
    -- Bandera aparte para poder quitar el convenio. Sin esto no habría forma de
    -- distinguir "no me mandaron convenio" de "quiero dejarlo sin convenio",
    -- porque los dos casos llegan como NULL.
    p_quitar_convenio BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_actual RECORD;
    v_error TEXT;
    -- Valores finales: lo que quedará guardado si todo pasa la validación.
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

    -- Mezclo lo que llega con lo que ya había.
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

    -- Si cambió el documento, reviso que no choque con otra ficha.
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
        -- El apellido materno y la dirección sí admiten quedar vacíos, así que
        -- los trato distinto: uso el valor que llega tal cual cuando viene.
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
