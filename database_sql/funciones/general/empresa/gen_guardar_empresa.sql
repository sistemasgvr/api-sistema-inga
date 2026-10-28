-- Crea la empresa o actualiza la activa: RUC, razón social, nombre comercial,
-- dirección, distrito (ubigeo para SUNAT) y tasa de IGV del régimen vigente.
-- p_datos: ruc, razon_social, nombre_comercial, direccion, id_distrito, tasa_igv.
DROP FUNCTION IF EXISTS gen_guardar_empresa(p_datos JSONB, p_id_usuario_auditoria BIGINT);
CREATE OR REPLACE FUNCTION gen_guardar_empresa(
    p_datos JSONB,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_ruc VARCHAR := TRIM(p_datos->>'ruc');
    v_id_distrito BIGINT := (p_datos->>'id_distrito')::BIGINT;
    v_tasa_igv NUMERIC := COALESCE((p_datos->>'tasa_igv')::NUMERIC, 18);
BEGIN
    IF v_ruc !~ '^[0-9]{11}$' THEN
        RETURN json_build_object('error', 'El RUC debe tener 11 dígitos', 'registro', NULL);
    END IF;

    IF NULLIF(TRIM(p_datos->>'razon_social'), '') IS NULL THEN
        RETURN json_build_object('error', 'La razón social es obligatoria', 'registro', NULL);
    END IF;

    IF v_tasa_igv < 0 OR v_tasa_igv > 100 THEN
        RETURN json_build_object('error', 'La tasa de IGV debe estar entre 0 y 100', 'registro', NULL);
    END IF;

    IF v_id_distrito IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_distrito WHERE id = v_id_distrito
    ) THEN
        RETURN json_build_object('error', 'El distrito seleccionado no existe', 'registro', NULL);
    END IF;

    SELECT id INTO v_id
    FROM gen_empresa
    WHERE estado = 1
    ORDER BY id
    LIMIT 1;

    IF EXISTS (
        SELECT 1 FROM gen_empresa
        WHERE ruc = v_ruc
          AND id IS DISTINCT FROM v_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otra empresa registrada con ese RUC', 'registro', NULL);
    END IF;

    IF v_id IS NULL THEN
        INSERT INTO gen_empresa (
            ruc,
            razon_social,
            nombre_comercial,
            direccion,
            id_distrito,
            tasa_igv,
            id_usuario_creacion,
            id_usuario_modificacion
        )
        VALUES (
            v_ruc,
            TRIM(p_datos->>'razon_social'),
            NULLIF(TRIM(p_datos->>'nombre_comercial'), ''),
            NULLIF(TRIM(p_datos->>'direccion'), ''),
            v_id_distrito,
            v_tasa_igv,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    ELSE
        UPDATE gen_empresa
        SET ruc = v_ruc,
            razon_social = TRIM(p_datos->>'razon_social'),
            nombre_comercial = NULLIF(TRIM(p_datos->>'nombre_comercial'), ''),
            direccion = NULLIF(TRIM(p_datos->>'direccion'), ''),
            id_distrito = v_id_distrito,
            tasa_igv = v_tasa_igv,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = v_id;
    END IF;

    RETURN gen_obtener_empresa();
END;
$function$;
