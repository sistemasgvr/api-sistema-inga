-- Actualizo un trabajador. Lo que llega en NULL se queda como está.
DROP FUNCTION IF EXISTS pla_actualizar_trabajador(
    p_id BIGINT,
    p_nombres VARCHAR,
    p_apellidos VARCHAR,
    p_num_documento VARCHAR,
    p_puesto VARCHAR,
    p_sueldo_referencial NUMERIC,
    p_id_sucursal BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_email VARCHAR,
    p_telefono VARCHAR
);
DROP FUNCTION IF EXISTS pla_actualizar_trabajador(
    p_id BIGINT,
    p_nombres VARCHAR,
    p_apellidos VARCHAR,
    p_num_documento VARCHAR,
    p_puesto VARCHAR,
    p_sueldo_referencial NUMERIC,
    p_id_sucursal BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_email VARCHAR,
    p_telefono VARCHAR,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pla_actualizar_trabajador(
    p_id BIGINT,
    p_nombres VARCHAR DEFAULT NULL,
    p_apellidos VARCHAR DEFAULT NULL,
    p_num_documento VARCHAR DEFAULT NULL,
    p_puesto VARCHAR DEFAULT NULL,
    p_sueldo_referencial NUMERIC DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    -- Solo completa la empresa si el trabajador aún no tiene una (no se cambia de empresa).
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombres VARCHAR;
    v_apellidos VARCHAR;
    v_doc VARCHAR;
    v_empresa BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombres := NULLIF(TRIM(p_nombres), '');
    v_apellidos := NULLIF(TRIM(p_apellidos), '');
    v_doc := NULLIF(TRIM(p_num_documento), '');

    PERFORM 1 FROM pla_trabajador WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El trabajador no existe o está inactivo', 'registro', NULL);
    END IF;

    IF v_doc IS NOT NULL AND v_doc !~ '^[A-Za-z0-9]{8,12}$' THEN
        RETURN json_build_object(
            'error', 'El documento debe tener entre 8 y 12 caracteres alfanuméricos',
            'registro', NULL
        );
    END IF;

    IF v_doc IS NOT NULL AND EXISTS (
        SELECT 1 FROM pla_trabajador WHERE num_documento = v_doc AND id <> p_id
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe otro trabajador con el documento ' || v_doc,
            'registro', NULL
        );
    END IF;

    IF p_sueldo_referencial IS NOT NULL AND p_sueldo_referencial < 0 THEN
        RETURN json_build_object('error', 'El sueldo referencial no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    SELECT COALESCE(t.id_empresa, p_id_empresa, s.id_empresa)
    INTO v_empresa
    FROM pla_trabajador t
    LEFT JOIN gen_sucursal s ON s.id = COALESCE(p_id_sucursal, t.id_sucursal)
    WHERE t.id = p_id;

    IF p_id_sucursal IS NOT NULL AND v_empresa IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND id_empresa = v_empresa
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada pertenece a otra empresa', 'registro', NULL);
    END IF;

    IF p_email IS NOT NULL AND NULLIF(TRIM(p_email), '') IS NULL
       AND EXISTS (SELECT 1 FROM auth_usuario WHERE id_trabajador = p_id) THEN
        RAISE EXCEPTION 'Un trabajador con usuario debe conservar un correo electrónico.';
    END IF;
    UPDATE pla_trabajador
    SET
        email = CASE WHEN p_email IS NULL THEN email ELSE NULLIF(LOWER(TRIM(p_email)), '') END,
        telefono = CASE WHEN p_telefono IS NULL THEN telefono ELSE NULLIF(TRIM(p_telefono), '') END,
        nombres = COALESCE(v_nombres, nombres),
        apellidos = COALESCE(v_apellidos, apellidos),
        num_documento = COALESCE(v_doc, num_documento),
        puesto = COALESCE(NULLIF(TRIM(p_puesto), ''), puesto),
        sueldo_referencial = COALESCE(p_sueldo_referencial, sueldo_referencial),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_empresa = COALESCE(id_empresa, v_empresa),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN pla_obtener_trabajador(p_id);
END;
$function$;
