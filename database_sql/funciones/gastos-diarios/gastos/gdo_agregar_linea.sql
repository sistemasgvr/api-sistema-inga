-- Agrego una compra al gasto del día. Si es a crédito genera el cargo en CxP (exige proveedor);
-- si es en efectivo exige turno abierto. Un producto de inventario además ingresa stock (ENTRADA por COMPRA).
DROP FUNCTION IF EXISTS gdo_agregar_linea(BIGINT, BIGINT, NUMERIC, NUMERIC, SMALLINT, BIGINT, BIGINT, VARCHAR, BIGINT);
CREATE OR REPLACE FUNCTION gdo_agregar_linea(
    p_id_gasto_dia BIGINT,
    p_id_insumo BIGINT,
    p_cantidad NUMERIC,
    p_precio_unitario NUMERIC,
    p_forma_pago SMALLINT DEFAULT 1,
    p_id_unidad_medida BIGINT DEFAULT NULL,
    p_id_proveedor BIGINT DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_producto BIGINT DEFAULT NULL,
    p_id_almacen BIGINT DEFAULT NULL
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
    -- JSONB para usar -> y ->> sobre el resultado de cxp_registrar_cargo.
    v_cargo JSONB;
    v_nombre_insumo VARCHAR;
    v_producto RECORD;
    v_id_unidad BIGINT;
    v_id_almacen BIGINT;
    v_id_mov BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id, id_sucursal, id_turno, fecha_gasto, estado
    INTO v_dia
    FROM gdo_gasto_dia WHERE id = p_id_gasto_dia AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El gasto del día no existe o fue anulado', 'registro', NULL);
    END IF;

    IF (p_id_insumo IS NULL) = (p_id_producto IS NULL) THEN
        RETURN json_build_object(
            'error', 'Elija un producto del inventario o un insumo de la lista, no ambos',
            'registro', NULL
        );
    END IF;

    v_id_unidad := p_id_unidad_medida;

    IF p_id_insumo IS NOT NULL THEN
        SELECT nombre INTO v_nombre_insumo
        FROM gdo_insumo WHERE id = p_id_insumo AND estado = 1;

        IF v_nombre_insumo IS NULL THEN
            RETURN json_build_object('error', 'El insumo indicado no existe o está inactivo', 'registro', NULL);
        END IF;
    ELSE
        SELECT pr.nombre, pr.id_unidad_medida, pr.id_almacen_stock, pr.controla_stock,
               COALESCE(tp.requiere_receta AND NOT tp.permite_stock_inicial, FALSE) AS solo_receta
        INTO v_producto
        FROM pro_producto pr
        LEFT JOIN pro_tipo_producto tp ON tp.id = pr.tipo_producto
        WHERE pr.id = p_id_producto AND pr.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF NOT v_producto.controla_stock THEN
            RETURN json_build_object(
                'error', v_producto.nombre || ' no controla stock: regístrelo como insumo de la lista',
                'registro', NULL
            );
        END IF;

        IF v_producto.solo_receta THEN
            RETURN json_build_object(
                'error', v_producto.nombre || ' se prepara con su receta, no se compra',
                'registro', NULL
            );
        END IF;

        IF p_id_usuario_auditoria IS NULL THEN
            RETURN json_build_object('error', 'No se identificó al usuario que registra la compra', 'registro', NULL);
        END IF;

        v_nombre_insumo := v_producto.nombre;
        v_id_unidad := v_producto.id_unidad_medida;

        -- Almacén: el elegido, si no el habitual del producto, si no el principal de crudos de la sucursal.
        v_id_almacen := COALESCE(p_id_almacen, v_producto.id_almacen_stock);
        IF v_id_almacen IS NULL THEN
            SELECT a.id INTO v_id_almacen
            FROM gen_almacen a
            WHERE a.estado = 1 AND a.tipo_almacen = 1
              AND (v_dia.id_sucursal IS NULL OR a.id_sucursal = v_dia.id_sucursal)
            ORDER BY a.es_principal DESC, a.id
            LIMIT 1;
        END IF;

        IF v_id_almacen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = v_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'Indique un almacén activo donde ingresar la compra', 'registro', NULL);
        END IF;
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

    IF v_id_unidad IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_unidad_medida WHERE id = v_id_unidad AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La unidad de medida indicada no existe', 'registro', NULL);
    END IF;

    v_subtotal := ROUND(p_cantidad * p_precio_unitario, 2);

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

    -- Todo en un bloque: si el ingreso a inventario falla se deshacen también el cargo y la línea.
    BEGIN
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

            IF v_cargo->>'error' IS NOT NULL THEN
                RETURN json_build_object(
                    'error', 'No se pudo generar la deuda al proveedor: ' || (v_cargo->>'error'),
                    'registro', NULL
                );
            END IF;

            v_id_cxp := (v_cargo->'registro'->>'id')::BIGINT;
        END IF;

        INSERT INTO gdo_gasto_detalle (
            id_gasto_dia, id_insumo, id_producto, id_almacen, id_unidad_medida,
            id_proveedor, id_cxp_movimiento,
            cantidad, precio_unitario, subtotal, forma_pago, observacion,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_id_gasto_dia, p_id_insumo, p_id_producto, v_id_almacen, v_id_unidad,
            p_id_proveedor, v_id_cxp,
            p_cantidad, p_precio_unitario, v_subtotal,
            COALESCE(p_forma_pago, 1),
            NULLIF(TRIM(p_observacion), ''),
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

        IF v_id_cxp IS NOT NULL THEN
            UPDATE cxp_movimiento SET id_gasto_diario = v_id WHERE id = v_id_cxp;
        END IF;

        IF p_id_producto IS NOT NULL THEN
            v_id_mov := alm_aplicar(
                'GDO-' || v_id, 'ENTRADA', 'COMPRA', 'gdo_gasto_detalle', v_id,
                jsonb_build_array(jsonb_build_object(
                    'id_producto', p_id_producto,
                    'id_almacen', v_id_almacen,
                    'id_unidad_medida', v_id_unidad,
                    'cantidad', p_cantidad,
                    'signo', 1,
                    'costo_unitario', p_precio_unitario,
                    'observacion', 'Compra del día ' || TO_CHAR(v_dia.fecha_gasto, 'DD/MM/YYYY')
                )),
                p_id_usuario_auditoria
            );

            UPDATE gdo_gasto_detalle SET id_alm_movimiento = v_id_mov WHERE id = v_id;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('error', 'No se pudo registrar la compra: ' || SQLERRM, 'registro', NULL);
    END;

    IF p_id_insumo IS NOT NULL THEN
        UPDATE gdo_insumo
        SET precio_referencial = p_precio_unitario,
            id_usuario_modificacion = p_id_usuario_auditoria
        WHERE id = p_id_insumo;
    END IF;

    PERFORM gdo_recalcular_totales_dia(p_id_gasto_dia);

    RETURN gdo_obtener_dia(p_id_gasto_dia);
END;
$function$;
