DROP FUNCTION IF EXISTS caj_actualizar_caja(
    p_id BIGINT,
    p_id_sucursal BIGINT,
    p_nombre VARCHAR,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION caj_actualizar_caja(
    p_id BIGINT,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
    v_id_sucursal BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    SELECT COALESCE(p_id_sucursal, id_sucursal) INTO v_id_sucursal
    FROM caj_caja WHERE id = p_id AND estado = 1;

    IF v_id_sucursal IS NULL THEN
        RETURN json_build_object('error', 'La caja no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NOT NULL AND EXISTS (
        SELECT 1 FROM caj_turno
        WHERE id_caja = p_id AND estado_turno = 1 AND estado = 1
    ) AND p_id_sucursal <> (SELECT id_sucursal FROM caj_caja WHERE id = p_id) THEN
        RETURN json_build_object(
            'error', 'No se puede cambiar la sucursal mientras la caja tenga un turno abierto',
            'registro', NULL
        );
    END IF;

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM caj_caja
        WHERE id_sucursal = v_id_sucursal AND estado = 1
          AND LOWER(nombre) = LOWER(v_nombre) AND id <> p_id
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe otra caja con el nombre ' || v_nombre || ' en esta sucursal',
            'registro', NULL
        );
    END IF;

    UPDATE caj_caja
    SET
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        nombre = COALESCE(v_nombre, nombre),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN caj_obtener_caja(p_id);
END;
$function$;
