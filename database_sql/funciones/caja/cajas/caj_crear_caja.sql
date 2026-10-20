-- Creo una caja física.
--
-- El nombre es único por sucursal, no global: dos locales pueden tener cada
-- uno su "Caja principal" sin pisarse.
CREATE OR REPLACE FUNCTION caj_crear_caja(
    p_id_sucursal BIGINT,
    p_nombre VARCHAR,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre de la caja es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM caj_caja
        WHERE id_sucursal = p_id_sucursal AND estado = 1
          AND LOWER(nombre) = LOWER(v_nombre)
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe una caja con el nombre ' || v_nombre || ' en esta sucursal',
            'registro', NULL
        );
    END IF;

    INSERT INTO caj_caja (
        id_sucursal, nombre, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_sucursal, v_nombre, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN caj_obtener_caja(v_id);
END;
$function$;
