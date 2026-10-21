DROP FUNCTION IF EXISTS gen_crear_estacion(
    p_id_sucursal BIGINT,
    p_nombre VARCHAR,
    p_tipo_estacion INTEGER,
    p_impresora_nombre VARCHAR,
    p_impresora_ip VARCHAR,
    p_usa_kds BOOLEAN,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gen_crear_estacion(
    p_id_sucursal BIGINT,
    p_nombre VARCHAR,
    p_tipo_estacion INTEGER DEFAULT 1,
    p_impresora_nombre VARCHAR DEFAULT NULL,
    p_impresora_ip VARCHAR DEFAULT NULL,
    p_usa_kds BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre de la estación es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM gen_estacion
        WHERE estado = 1
          AND id_sucursal = p_id_sucursal
          AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre))
    ) THEN
        RETURN json_build_object('error', 'Ya existe una estación activa con el nombre ' || TRIM(p_nombre) || ' en esta sucursal', 'registro', NULL);
    END IF;

    INSERT INTO gen_estacion (
        id_sucursal,
        nombre,
        tipo_estacion,
        impresora_nombre,
        impresora_ip,
        usa_kds,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_sucursal,
        TRIM(p_nombre),
        p_tipo_estacion,
        NULLIF(TRIM(p_impresora_nombre), ''),
        NULLIF(TRIM(p_impresora_ip), ''),
        p_usa_kds,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_estacion(v_id);
END;
$function$;
