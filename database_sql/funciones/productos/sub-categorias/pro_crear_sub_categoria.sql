DROP FUNCTION IF EXISTS pro_crear_sub_categoria(
    p_id_categoria BIGINT,
    p_nombre VARCHAR,
    p_orden INTEGER,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pro_crear_sub_categoria(
    p_id_categoria BIGINT,
    p_nombre VARCHAR,
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

    v_empresa := COALESCE(p_id_empresa, (SELECT t.id_empresa FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador WHERE u.id = p_id_usuario_auditoria), (SELECT c.id_empresa FROM pro_categoria c WHERE c.id = p_id_categoria));

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre de la subcategoría es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_categoria WHERE id = p_id_categoria AND estado = 1
          AND (v_empresa IS NULL OR id_empresa = v_empresa)
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_subcategoria
        WHERE estado = 1
          AND id_categoria = p_id_categoria
          AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre))
          AND (v_empresa IS NULL OR id_empresa = v_empresa)
    ) THEN
        RETURN json_build_object('error', 'Ya existe una subcategoría activa con el nombre ' || TRIM(p_nombre) || ' en esta categoría', 'registro', NULL);
    END IF;

    INSERT INTO pro_subcategoria (
        id_empresa,
        id_categoria,
        nombre,
        orden,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_empresa,
        p_id_categoria,
        TRIM(p_nombre),
        COALESCE(p_orden, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_sub_categoria(v_id, v_empresa);
END;
$function$;