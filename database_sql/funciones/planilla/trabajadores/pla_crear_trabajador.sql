-- Creo un trabajador.
--
-- El documento es opcional (el cliente pidió el registro mínimo), pero si se
-- informa tiene que ser único: la restricción uq_pla_trabajador_doc lo impone.
-- Valido el duplicado acá para dar un mensaje claro en vez de dejar que
-- reviente el UNIQUE con un error crudo de Postgres.
CREATE OR REPLACE FUNCTION pla_crear_trabajador(
    p_nombres VARCHAR,
    p_apellidos VARCHAR,
    p_num_documento VARCHAR DEFAULT NULL,
    p_puesto VARCHAR DEFAULT NULL,
    p_sueldo_referencial NUMERIC DEFAULT 0,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_nombres VARCHAR;
    v_apellidos VARCHAR;
    v_doc VARCHAR;
    v_existente RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombres := NULLIF(TRIM(p_nombres), '');
    v_apellidos := NULLIF(TRIM(p_apellidos), '');
    v_doc := NULLIF(TRIM(p_num_documento), '');

    IF v_nombres IS NULL THEN
        RETURN json_build_object('error', 'Los nombres del trabajador son obligatorios', 'registro', NULL);
    END IF;

    IF v_apellidos IS NULL THEN
        RETURN json_build_object('error', 'Los apellidos del trabajador son obligatorios', 'registro', NULL);
    END IF;

    -- Si informan documento, valido que sea DNI o carné: 8 a 12 alfanuméricos.
    -- No exijo 8 dígitos exactos como en cli_persona porque acá puede haber
    -- personal extranjero con carné, y el cliente pidió no complicar el alta.
    IF v_doc IS NOT NULL AND v_doc !~ '^[A-Za-z0-9]{8,12}$' THEN
        RETURN json_build_object(
            'error', 'El documento debe tener entre 8 y 12 caracteres alfanuméricos',
            'registro', NULL
        );
    END IF;

    IF COALESCE(p_sueldo_referencial, 0) < 0 THEN
        RETURN json_build_object('error', 'El sueldo referencial no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_doc IS NOT NULL THEN
        SELECT id, estado, nombres, apellidos INTO v_existente
        FROM pla_trabajador WHERE num_documento = v_doc;

        IF FOUND THEN
            -- Si existe pero está de baja, lo digo explícitamente: el usuario no
            -- lo ve en la lista y sin este aviso quedaría peleando con un error
            -- de "documento repetido" sobre alguien invisible.
            IF v_existente.estado = 0 THEN
                RETURN json_build_object(
                    'error', 'Ya existe un trabajador dado de baja con el documento ' || v_doc ||
                             ' (' || v_existente.nombres || ' ' || v_existente.apellidos ||
                             '). Reactívalo desde el filtro de inactivos.',
                    'registro', NULL
                );
            END IF;
            RETURN json_build_object(
                'error', 'Ya existe un trabajador con el documento ' || v_doc,
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO pla_trabajador (
        id_sucursal, nombres, apellidos, num_documento, puesto,
        sueldo_referencial, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_sucursal, v_nombres, v_apellidos, v_doc,
        NULLIF(TRIM(p_puesto), ''), COALESCE(p_sueldo_referencial, 0),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pla_obtener_trabajador(v_id);
END;
$function$;
