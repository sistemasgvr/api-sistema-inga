CREATE OR REPLACE FUNCTION gen_crear_almacen(
    p_id_sucursal BIGINT,
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
    p_tipo_almacen INTEGER DEFAULT 1,
    p_es_principal BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_codigo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := UPPER(TRIM(p_codigo));

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre del almacén es obligatorio', 'registro', NULL);
    END IF;

    IF v_codigo IS NULL OR v_codigo = '' THEN
        RETURN json_build_object('error', 'El código del almacén es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM gen_almacen
        WHERE estado = 1
          AND id_sucursal = p_id_sucursal
          AND codigo = v_codigo
    ) THEN
        RETURN json_build_object('error', 'Ya existe un almacén activo con el código ' || v_codigo || ' en esta sucursal', 'registro', NULL);
    END IF;

    INSERT INTO gen_almacen (
        id_sucursal,
        codigo,
        nombre,
        descripcion,
        tipo_almacen,
        es_principal,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_sucursal,
        v_codigo,
        TRIM(p_nombre),
        NULLIF(TRIM(p_descripcion), ''),
        p_tipo_almacen,
        p_es_principal,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_almacen(v_id);
END;
$function$;