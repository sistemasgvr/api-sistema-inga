-- Abre (o recupera) el registro de gasto de un día.
--
-- Es idempotente a propósito: si el día ya existe lo devuelve en vez de fallar.
-- El cajero no debería tener que pensar en "crear el día"; simplemente entra a
-- la pantalla, y si es la primera compra de la jornada el día se crea solo.
--
-- El índice uq_gdo_gasto_dia garantiza uno por fecha y sucursal.
CREATE OR REPLACE FUNCTION gdo_abrir_dia(
    p_fecha_gasto DATE DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_id_turno BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_gasto, CURRENT_DATE);

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object(
            'error', 'No se puede abrir el gasto de un día futuro',
            'registro', NULL
        );
    END IF;

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La sucursal indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    -- ¿Ya existe? Lo devuelvo tal cual.
    SELECT id INTO v_id
    FROM gdo_gasto_dia
    WHERE fecha_gasto = v_fecha
      AND COALESCE(id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
      AND estado = 1;

    IF FOUND THEN
        RETURN gdo_obtener_dia(v_id);
    END IF;

    INSERT INTO gdo_gasto_dia (
        id_sucursal, id_turno, fecha_gasto, anio, mes,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_sucursal, p_id_turno, v_fecha,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gdo_obtener_dia(v_id);
END;
$function$;
