DROP FUNCTION IF EXISTS pro_crear_categoria(
    p_nombre VARCHAR,
    p_descripcion VARCHAR,
    p_es_carta BOOLEAN,
    p_orden INTEGER,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pro_crear_categoria(
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_es_carta BOOLEAN DEFAULT FALSE,
    p_orden INTEGER DEFAULT 0,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_empresa BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_empresa := COALESCE(p_id_empresa, (SELECT t.id_empresa FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador WHERE u.id = p_id_usuario_auditoria));

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre de la categoría es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_categoria
        WHERE estado = 1
          AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre))
          AND (v_empresa IS NULL OR id_empresa = v_empresa)
    ) THEN
        RETURN json_build_object('error', 'Ya existe una categoría con el nombre ' || TRIM(p_nombre), 'registro', NULL);
    END IF;

    INSERT INTO pro_categoria (
        id_empresa,
        nombre,
        descripcion,
        es_carta,
        orden,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_empresa,
        TRIM(p_nombre),
        NULLIF(TRIM(p_descripcion), ''),
        COALESCE(p_es_carta, FALSE),
        COALESCE(p_orden, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_categoria(v_id, v_empresa);
END;
$function$;