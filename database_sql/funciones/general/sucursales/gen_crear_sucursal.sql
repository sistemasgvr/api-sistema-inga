CREATE OR REPLACE FUNCTION gen_crear_sucursal(
    p_id_empresa BIGINT,
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_direccion VARCHAR DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_id_distrito BIGINT DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    IF EXISTS (
        SELECT 1 FROM gen_sucursal 
        WHERE LOWER(codigo) = LOWER(p_codigo) 
          AND id_empresa = p_id_empresa 
          AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El código de sucursal ya existe para esta empresa', 'registro', NULL);
    END IF;

    IF p_es_principal = TRUE THEN
        UPDATE gen_sucursal 
        SET es_principal = FALSE, id_usuario_modificacion = p_id_usuario_auditoria
        WHERE id_empresa = p_id_empresa;
    END IF;

    INSERT INTO gen_sucursal (
        id_empresa,
        codigo,
        nombre,
        direccion,
        telefono,
        id_distrito,
        es_principal,
        estado,
        id_usuario_creacion
    )
    VALUES (
        p_id_empresa,
        UPPER(p_codigo),
        p_nombre,
        p_direccion,
        p_telefono,
        p_id_distrito,
        COALESCE(p_es_principal, FALSE),
        1,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_sucursal(v_id);
END;
$function$;