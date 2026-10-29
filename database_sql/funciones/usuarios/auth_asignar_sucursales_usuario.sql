-- Reemplaza las sucursales del usuario por las indicadas y marca la predeterminada
-- (si no se indica, la primera). Todas deben ser de la empresa del usuario: lo
-- valida el trigger de auth_usuario_sucursal.
-- p_sucursales: [1, 2, 3]
DROP FUNCTION IF EXISTS auth_asignar_sucursales_usuario(
    p_id_usuario BIGINT,
    p_sucursales JSON,
    p_id_sucursal_predeterminada BIGINT,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION auth_asignar_sucursales_usuario(
    p_id_usuario BIGINT,
    p_sucursales JSON,
    p_id_sucursal_predeterminada BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_ids BIGINT[];
    v_predeterminada BIGINT;
BEGIN
    SELECT COALESCE(array_agg(DISTINCT x::BIGINT), '{}')
    INTO v_ids
    FROM json_array_elements_text(COALESCE(p_sucursales, '[]'::JSON)) x;

    IF cardinality(v_ids) = 0 THEN
        RAISE EXCEPTION 'Asigne al menos una sucursal al usuario';
    END IF;

    IF EXISTS (
        SELECT 1 FROM unnest(v_ids) i
        WHERE NOT EXISTS (SELECT 1 FROM gen_sucursal s WHERE s.id = i AND s.estado = 1)
    ) THEN
        RAISE EXCEPTION 'Una de las sucursales no existe o está inactiva';
    END IF;

    v_predeterminada := COALESCE(p_id_sucursal_predeterminada, v_ids[1]);
    IF NOT v_predeterminada = ANY(v_ids) THEN
        RAISE EXCEPTION 'La sucursal predeterminada debe estar entre las sucursales asignadas';
    END IF;

    -- Primero se liberan todas (la predeterminada es única), luego se activan las elegidas.
    UPDATE auth_usuario_sucursal
    SET estado = CASE WHEN id_sucursal = ANY(v_ids) THEN estado ELSE 0 END,
        es_predeterminada = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id_usuario = p_id_usuario;

    INSERT INTO auth_usuario_sucursal (
        id_usuario,
        id_sucursal,
        es_predeterminada,
        estado,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    SELECT
        p_id_usuario,
        i,
        i = v_predeterminada,
        1,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    FROM unnest(v_ids) i
    ON CONFLICT ON CONSTRAINT uq_auth_usuario_sucursal DO UPDATE SET
        estado = 1,
        es_predeterminada = EXCLUDED.es_predeterminada,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = CURRENT_TIMESTAMP;

    -- Las sesiones abiertas en una sucursal que ya no tiene vuelven a la predeterminada.
    UPDATE auth_sesion
    SET id_sucursal_activa = v_predeterminada
    WHERE id_usuario = p_id_usuario
      AND estado = 1
      AND (id_sucursal_activa IS NULL OR NOT id_sucursal_activa = ANY(v_ids));

    RETURN auth_sucursales_usuario(p_id_usuario);
END;
$function$;
