-- Registro un gasto administrativo.
--
-- El período (anio/mes) lo derivo de la fecha del gasto, no lo pido. A
-- diferencia de planilla, acá la regla es directa: un gasto del 5 de octubre
-- pertenece a octubre. Lo guardo denormalizado en las columnas anio/mes para
-- poder agrupar por período sin funciones de fecha en cada consulta del reporte.
--
-- Si el gasto se paga en efectivo, exijo un turno de caja abierto: ese dinero
-- sale del cajón y sin el vínculo el cuadre del día no cerraría. Es la misma
-- regla que apliqué en planilla (M17).
CREATE OR REPLACE FUNCTION gad_registrar_gasto(
    p_id_categoria BIGINT,
    p_concepto VARCHAR,
    p_monto NUMERIC,
    p_fecha_gasto DATE DEFAULT NULL,
    p_medio_pago SMALLINT DEFAULT 1,
    p_id_turno BIGINT DEFAULT NULL,
    p_id_persona BIGINT DEFAULT NULL,
    p_num_comprobante VARCHAR DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
    v_concepto VARCHAR;
    v_estado_turno SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_gasto, CURRENT_DATE);
    v_concepto := NULLIF(TRIM(p_concepto), '');

    IF NOT EXISTS (
        SELECT 1 FROM gad_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'La categoría de gasto indicada no existe o está inactiva',
            'registro', NULL
        );
    END IF;

    IF v_concepto IS NULL THEN
        RETURN json_build_object(
            'error', 'El concepto es obligatorio: sin él, al revisar el mes nadie sabe de qué fue el gasto',
            'registro', NULL
        );
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF COALESCE(p_medio_pago, 1) NOT IN (1, 2, 3) THEN
        RETURN json_build_object(
            'error', 'El medio de pago debe ser efectivo, Yape o tarjeta/transferencia',
            'registro', NULL
        );
    END IF;

    -- Un gasto con fecha futura descuadraría la caja de un día que no ha pasado.
    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object(
            'error', 'No se puede registrar un gasto con fecha futura',
            'registro', NULL
        );
    END IF;

    IF p_id_persona IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_persona WHERE id = p_id_persona AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El proveedor indicado no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_sucursal WHERE id = p_id_sucursal AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'La sucursal indicada no existe o está inactiva',
            'registro', NULL
        );
    END IF;

    IF COALESCE(p_medio_pago, 1) = 1 THEN
        IF p_id_turno IS NULL THEN
            RETURN json_build_object(
                'error', 'Un gasto en efectivo debe registrarse contra un turno de caja abierto',
                'registro', NULL
            );
        END IF;

        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = p_id_turno AND estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El turno de caja indicado no existe', 'registro', NULL);
        END IF;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'error', 'No se puede registrar el gasto: el turno de caja ya está cerrado',
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO gad_gasto (
        id_categoria, id_sucursal, id_turno, id_persona,
        concepto, monto, fecha_gasto,
        anio, mes, medio_pago, num_comprobante, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_categoria, p_id_sucursal, p_id_turno, p_id_persona,
        v_concepto, p_monto, v_fecha,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        COALESCE(p_medio_pago, 1),
        NULLIF(TRIM(p_num_comprobante), ''),
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gad_obtener_gasto(v_id);
END;
$function$;
