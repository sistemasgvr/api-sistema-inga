CREATE OR REPLACE FUNCTION gen_actualizar_almacen(
    p_id BIGINT,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_tipo_almacen INTEGER DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT NULL,
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
    FROM gen_almacen
    WHERE id = p_id AND estado = 1;

    IF v_id_sucursal IS NULL THEN
        RETURN json_build_object('error', 'El almacén no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_almacen
        WHERE estado = 1
          AND id_sucursal = v_id_sucursal
          AND LOWER(TRIM(nombre)) = LOWER(v_nombre)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro almacén activo con el nombre ' || v_nombre || ' en esta sucursal', 'registro', NULL);
    END IF;

    UPDATE gen_almacen
    SET
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        nombre = COALESCE(v_nombre, nombre),
        descripcion = COALESCE(p_descripcion, descripcion),
        tipo_almacen = COALESCE(p_tipo_almacen, tipo_almacen),
        es_principal = COALESCE(p_es_principal, es_principal),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN gen_obtener_almacen(p_id);
END;
$function$;
