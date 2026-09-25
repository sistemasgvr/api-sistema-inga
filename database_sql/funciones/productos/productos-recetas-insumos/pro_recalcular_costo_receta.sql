CREATE OR REPLACE FUNCTION pro_recalcular_costo_receta(p_id_receta BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_producto BIGINT;
    v_costo_total NUMERIC(12, 4);
BEGIN
    SELECT id_producto INTO v_id_producto
    FROM pro_receta
    WHERE id = p_id_receta AND estado = 1;

    IF v_id_producto IS NULL THEN
        RETURN;
    END IF;

    SELECT COALESCE(SUM(
        ri.cantidad * (1 + (ri.porcentaje_merma / 100.0)) * COALESCE(aps.costo_promedio, 0)
    ), 0)
    INTO v_costo_total
    FROM pro_receta_insumo ri
    JOIN pro_producto p ON p.id = ri.id_producto_insumo
    LEFT JOIN alm_producto_stock aps ON aps.id_producto = p.id AND aps.estado = 1
    WHERE ri.id_receta = p_id_receta AND ri.estado = 1;

    UPDATE pro_producto
    SET costo_receta_calculado = v_costo_total,
        fecha_modificacion = NOW()
    WHERE id = v_id_producto;
END;
$function$;
