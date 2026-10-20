CREATE OR REPLACE FUNCTION gen_actualizar_estacion(
    p_id BIGINT,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_tipo_estacion INTEGER DEFAULT NULL,
    p_impresora_nombre VARCHAR DEFAULT NULL,
    p_impresora_ip VARCHAR DEFAULT NULL,
    p_usa_kds BOOLEAN DEFAULT NULL,
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
    FROM gen_estacion
    WHERE id = p_id AND estado = 1;

    IF v_id_sucursal IS NULL THEN
        RETURN json_build_object('error', 'La estación no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_estacion
        WHERE estado = 1
          AND id_sucursal = v_id_sucursal
          AND LOWER(TRIM(nombre)) = LOWER(v_nombre)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otra estación activa con el nombre ' || v_nombre || ' en esta sucursal', 'registro', NULL);
    END IF;

    UPDATE gen_estacion
    SET
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        nombre = COALESCE(v_nombre, nombre),
        tipo_estacion = COALESCE(p_tipo_estacion, tipo_estacion),
        impresora_nombre = COALESCE(p_impresora_nombre, impresora_nombre),
        impresora_ip = COALESCE(p_impresora_ip, impresora_ip),
        usa_kds = COALESCE(p_usa_kds, usa_kds),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN gen_obtener_estacion(p_id);
END;
$function$;
