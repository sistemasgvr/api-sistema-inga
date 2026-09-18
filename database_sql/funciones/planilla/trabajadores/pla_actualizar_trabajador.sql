-- Actualizo un trabajador. Lo que llega en NULL se queda como está.
--
-- El "id <> p_id" al buscar documento duplicado es lo que permite guardar el
-- formulario sin cambiar el documento, sin que choque consigo mismo.
CREATE OR REPLACE FUNCTION pla_actualizar_trabajador(
    p_id BIGINT,
    p_nombres VARCHAR DEFAULT NULL,
    p_apellidos VARCHAR DEFAULT NULL,
    p_num_documento VARCHAR DEFAULT NULL,
    p_puesto VARCHAR DEFAULT NULL,
    p_sueldo_referencial NUMERIC DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombres VARCHAR;
    v_apellidos VARCHAR;
    v_doc VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombres := NULLIF(TRIM(p_nombres), '');
    v_apellidos := NULLIF(TRIM(p_apellidos), '');
    v_doc := NULLIF(TRIM(p_num_documento), '');

    IF NOT EXISTS (SELECT 1 FROM pla_trabajador WHERE id = p_id AND estado = 1) THEN
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

    UPDATE pla_trabajador
    SET
        nombres = COALESCE(v_nombres, nombres),
        apellidos = COALESCE(v_apellidos, apellidos),
        num_documento = COALESCE(v_doc, num_documento),
        puesto = COALESCE(NULLIF(TRIM(p_puesto), ''), puesto),
        sueldo_referencial = COALESCE(p_sueldo_referencial, sueldo_referencial),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN pla_obtener_trabajador(p_id);
END;
$function$;
