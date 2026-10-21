-- El código se deriva del nombre ("Jefe de Barra" → JEFE_DE_BARRA); el sistema reconoce
-- al administrador por su código 'ADMIN'.
DROP FUNCTION IF EXISTS auth_crear_rol(
    p_nombre VARCHAR,
    p_descripcion VARCHAR,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION auth_crear_rol(
    p_nombre VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_nombre VARCHAR;
    v_base VARCHAR;
    v_codigo VARCHAR;
    v_sufijo INTEGER := 1;
BEGIN
    PERFORM set_config('timezone', 'America/Lima', true);

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre del rol es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM auth_rol WHERE LOWER(nombre) = LOWER(v_nombre) AND estado = 1) THEN
        RETURN json_build_object('error', 'Ya existe un rol con el nombre ' || v_nombre, 'registro', NULL);
    END IF;

    v_base := LEFT(TRIM(BOTH '_' FROM regexp_replace(
        UPPER(translate(v_nombre, 'áéíóúàèìòùäëïöüñÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÑ', 'aeiouaeiouaeiounAEIOUAEIOUAEIOUN')),
        '[^A-Z0-9]+', '_', 'g'
    )), 44);
    IF v_base = '' THEN
        v_base := 'ROL';
    END IF;

    -- El UNIQUE de codigo no mira el estado: un rol dado de baja también lo ocupa.
    v_codigo := v_base;
    WHILE EXISTS (SELECT 1 FROM auth_rol WHERE codigo = v_codigo) LOOP
        v_sufijo := v_sufijo + 1;
        v_codigo := v_base || '_' || v_sufijo;
    END LOOP;

    INSERT INTO auth_rol (
        codigo,
        nombre,
        descripcion,
        estado,
        id_usuario_creacion
    )
    VALUES (
        v_codigo,
        v_nombre,
        p_descripcion,
        1,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN auth_obtener_rol(v_id);
END;
$function$;
