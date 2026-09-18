-- Agrego una compra al gasto del día.
--
-- Es la función más importante del módulo, porque es donde se cierra el
-- circuito con Cuentas por Pagar: **si la línea se marca como crédito
-- (forma_pago = 3), genero automáticamente el cargo en CxP**. Eso es
-- exactamente el requisito del alcance: "si el ítem se marca como crédito,
-- genera automáticamente una deuda del restaurante hacia ese proveedor".
--
-- Guardo el id del movimiento generado en la línea (id_cxp_movimiento) para
-- poder revertirlo si después se anula.
--
-- Tres reglas:
--   1. El crédito exige proveedor: la deuda tiene que quedar a nombre de alguien.
--   2. El efectivo exige turno de caja abierto, porque sale del cajón. Misma
--      regla que en planilla (M17), gastos administrativos (M16) y CxP (M15).
--   3. El Yape no exige nada: no toca el cajón ni genera deuda.
--
-- Al final actualizo el precio_referencial del insumo con lo que se acaba de
-- pagar. Así la próxima compra sugiere el precio real más reciente, que es como
-- el cliente lo tiene en su cabeza.
CREATE OR REPLACE FUNCTION gdo_agregar_linea(
    p_id_gasto_dia BIGINT,
    p_id_insumo BIGINT,
    p_cantidad NUMERIC,
    p_precio_unitario NUMERIC,
    p_forma_pago SMALLINT DEFAULT 1,
    p_id_unidad_medida BIGINT DEFAULT NULL,
    p_id_proveedor BIGINT DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_dia RECORD;
    v_subtotal NUMERIC(12,2);
    v_estado_turno SMALLINT;
    v_id_cxp BIGINT;
    -- JSONB y no JSON: necesito indexar con -> y ->> sobre el resultado, y
    -- esos operadores trabajan sobre jsonb. cxp_registrar_cargo devuelve JSON,
    -- así que lo casteo al asignarlo.
    v_cargo JSONB;
    v_nombre_insumo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id, id_turno, fecha_gasto, estado
    INTO v_dia
    FROM gdo_gasto_dia WHERE id = p_id_gasto_dia AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El gasto del día no existe o fue anulado', 'registro', NULL);
    END IF;

    SELECT nombre INTO v_nombre_insumo
    FROM gdo_insumo WHERE id = p_id_insumo AND estado = 1;

    IF v_nombre_insumo IS NULL THEN
        RETURN json_build_object('error', 'El insumo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF p_precio_unitario IS NULL OR p_precio_unitario < 0 THEN
        RETURN json_build_object('error', 'El precio no puede ser negativo', 'registro', NULL);
    END IF;

    IF COALESCE(p_forma_pago, 1) NOT IN (1, 2, 3) THEN
        RETURN json_build_object(
            'error', 'La forma de pago debe ser efectivo, Yape o crédito',
            'registro', NULL
        );
    END IF;

    IF p_id_unidad_medida IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_unidad_medida WHERE id = p_id_unidad_medida AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La unidad de medida indicada no existe', 'registro', NULL);
    END IF;

    v_subtotal := ROUND(p_cantidad * p_precio_unitario, 2);

    -- Regla 1: el crédito necesita proveedor.
    IF p_forma_pago = 3 THEN
        IF p_id_proveedor IS NULL THEN
            RETURN json_build_object(
                'error', 'Una compra a crédito debe indicar a qué proveedor se le debe',
                'registro', NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM cli_persona
            WHERE id = p_id_proveedor AND estado = 1 AND es_proveedor = TRUE
        ) THEN
            RETURN json_build_object(
                'error', 'El proveedor indicado no existe o no está marcado como proveedor',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Regla 2: el efectivo sale del cajón, así que exige turno abierto.
    IF p_forma_pago = 1 THEN
        IF v_dia.id_turno IS NULL THEN
            RETURN json_build_object(
                'error', 'Para registrar compras en efectivo, el día debe estar vinculado a un turno de caja abierto',
                'registro', NULL
            );
        END IF;

        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = v_dia.id_turno AND estado = 1;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'error', 'No se puede agregar: el turno de caja del día ya está cerrado',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Acá se cierra el circuito con M15: el cargo automático.
    IF p_forma_pago = 3 THEN
        v_cargo := cxp_registrar_cargo(
            p_id_proveedor,
            v_subtotal,
            v_dia.fecha_gasto,
            NULL,
            NULL, -- el id de la línea se enlaza justo después del INSERT
            'Compra diaria: ' || v_nombre_insumo,
            p_id_usuario_auditoria
        )::JSONB;

        -- Si CxP rechazó el cargo, corto acá y no dejo la línea a medias.
        IF v_cargo->>'error' IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'No se pudo generar la deuda al proveedor: ' || (v_cargo->>'error'),
                'registro', NULL
            );
        END IF;

        v_id_cxp := (v_cargo->'registro'->>'id')::BIGINT;
    END IF;

    INSERT INTO gdo_gasto_detalle (
        id_gasto_dia, id_insumo, id_unidad_medida, id_proveedor, id_cxp_movimiento,
        cantidad, precio_unitario, subtotal, forma_pago, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_gasto_dia, p_id_insumo, p_id_unidad_medida,
        p_id_proveedor, v_id_cxp,
        p_cantidad, p_precio_unitario, v_subtotal,
        COALESCE(p_forma_pago, 1),
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Cierro el enlace en la otra dirección, para que desde el movimiento de
    -- CxP se pueda llegar a la línea que lo originó.
    IF v_id_cxp IS NOT NULL THEN
        UPDATE cxp_movimiento SET id_gasto_diario = v_id WHERE id = v_id_cxp;
    END IF;

    -- El precio referencial sigue al último precio pagado.
    UPDATE gdo_insumo
    SET precio_referencial = p_precio_unitario,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id_insumo;

    PERFORM gdo_recalcular_totales_dia(p_id_gasto_dia);

    RETURN gdo_obtener_dia(p_id_gasto_dia);
END;
$function$;
