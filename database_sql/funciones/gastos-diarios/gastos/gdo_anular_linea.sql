-- Anulo una línea del gasto del día (baja lógica) revirtiendo su cargo en CxP y su ingreso de stock.
-- Falla si el cargo ya no es el último movimiento del proveedor, si el stock ya se consumió
-- o si fue en efectivo y su turno ya se cerró.
DROP FUNCTION IF EXISTS gdo_anular_linea(
    p_id BIGINT,
    p_motivo VARCHAR,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gdo_anular_linea(
    p_id BIGINT,
    p_motivo VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_linea RECORD;
    v_estado_turno SMALLINT;
    v_reverso JSONB;
    v_disponible NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT det.id, det.id_gasto_dia, det.forma_pago, det.id_cxp_movimiento,
           det.id_alm_movimiento, det.id_producto, det.id_almacen,
           det.id_unidad_medida, det.cantidad, det.precio_unitario,
           dia.id_turno
    INTO v_linea
    FROM gdo_gasto_detalle det
    INNER JOIN gdo_gasto_dia dia ON det.id_gasto_dia = dia.id
    WHERE det.id = p_id AND det.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La línea no existe o ya fue anulada', 'registro', NULL);
    END IF;

    IF v_linea.forma_pago = 1 AND v_linea.id_turno IS NOT NULL THEN
        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = v_linea.id_turno;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'error', 'No se puede anular: la compra fue en efectivo y el turno de caja del día ya está cerrado y arqueado.',
                'registro', NULL
            );
        END IF;
    END IF;

    IF v_linea.id_alm_movimiento IS NOT NULL THEN
        IF p_id_usuario_auditoria IS NULL THEN
            RETURN json_build_object('error', 'No se identificó al usuario que anula la compra', 'registro', NULL);
        END IF;

        SELECT COALESCE(stock_actual - stock_reservado, 0) INTO v_disponible
        FROM alm_producto_stock
        WHERE id_producto = v_linea.id_producto AND id_almacen = v_linea.id_almacen;

        IF COALESCE(v_disponible, 0) < v_linea.cantidad THEN
            RETURN json_build_object(
                'error', 'No se puede anular: el stock que ingresó esta compra ya se usó (disponible ' ||
                         TRIM(TO_CHAR(COALESCE(v_disponible, 0), 'FM999999990.####')) ||
                         '). Corrige el inventario con un ajuste.',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Los reversos van en un bloque: si sacar el stock falla, tampoco se anula la deuda.
    BEGIN
        IF v_linea.id_cxp_movimiento IS NOT NULL THEN
            v_reverso := cxp_anular_movimiento(
                v_linea.id_cxp_movimiento,
                'Anulación de compra diaria',
                p_id_usuario_auditoria
            )::JSONB;

            IF (v_reverso->>'eliminado')::BOOLEAN = FALSE THEN
                RETURN json_build_object(
                    'error', COALESCE(
                        v_reverso->>'error',
                        'No se pudo revertir la deuda generada en cuentas por pagar.'
                    ),
                    'registro', NULL
                );
            END IF;
        END IF;

        IF v_linea.id_alm_movimiento IS NOT NULL THEN
            PERFORM alm_registrar(jsonb_build_object(
                'codigo', 'GDO-ANU-' || v_linea.id,
                'id_tipo_movimiento', (
                    SELECT o.id FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
                    WHERE l.codigo = 'ALM_TIPO_MOVIMIENTO' AND o.codigo = 'SALIDA'),
                'id_motivo_movimiento', (
                    SELECT o.id FROM gen_lista_opcion o JOIN gen_lista l ON l.id = o.id_lista
                    WHERE l.codigo = 'ALM_MOTIVO_MOVIMIENTO' AND o.codigo = 'ANULACION_COMPRA'),
                'documento_tipo', 'gdo_gasto_detalle',
                'documento_id', v_linea.id,
                'id_movimiento_referencia', v_linea.id_alm_movimiento,
                'observacion', 'Anulación de compra del día: ' ||
                               COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado'),
                'confirmar', TRUE,
                'detalles', jsonb_build_array(jsonb_build_object(
                    'id_producto', v_linea.id_producto,
                    'id_almacen', v_linea.id_almacen,
                    'id_unidad_medida', v_linea.id_unidad_medida,
                    'cantidad', v_linea.cantidad,
                    'signo', -1
                ))
            ), p_id_usuario_auditoria);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('error', 'No se pudo anular la compra: ' || SQLERRM, 'registro', NULL);
    END;

    UPDATE gdo_gasto_detalle
    SET estado = 0,
        observacion = TRIM(BOTH ' ' FROM
            COALESCE(observacion || ' | ', '') ||
            'ANULADA: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado')
        ),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    PERFORM gdo_recalcular_totales_dia(v_linea.id_gasto_dia);

    RETURN gdo_obtener_dia(v_linea.id_gasto_dia);
END;
$function$;
