DROP FUNCTION IF EXISTS pro_recalcular_costo_receta(BIGINT);
DROP FUNCTION IF EXISTS pro_recalcular_costo_receta(BIGINT, INTEGER);

CREATE OR REPLACE FUNCTION pro_recalcular_costo_receta(p_id_receta BIGINT, p_profundidad INTEGER DEFAULT 0)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_producto BIGINT;
    v_costo_total NUMERIC(12, 4);
    v_padres BIGINT[];
    v_padre BIGINT;
BEGIN
    -- Red de seguridad ante un ciclo introducido por escrito directo en la base,
    -- saltándose pro_guardar_receta_insumo. Sin esto la cascada no terminaría.
    IF p_profundidad >= 20 THEN
        RETURN;
    END IF;

    SELECT id_producto INTO v_id_producto
    FROM pro_receta
    WHERE id = p_id_receta AND estado = 1;

    IF v_id_producto IS NULL THEN
        RETURN;
    END IF;

    -- El costo de cada insumo lo resuelve pro_costo_unitario_insumo, la misma
    -- función que usa pro_obtener_receta: así el detalle por insumo que ve el
    -- usuario suma exactamente este total.
    SELECT COALESCE(SUM(
        ri.cantidad * (1 + (ri.porcentaje_merma / 100.0))
        * pro_costo_unitario_insumo(ri.id_producto_insumo)
    ), 0)
    INTO v_costo_total
    FROM pro_receta_insumo ri
    WHERE ri.id_receta = p_id_receta AND ri.estado = 1;

    UPDATE pro_producto
    SET costo_receta_calculado = v_costo_total,
        fecha_modificacion = NOW()
    WHERE id = v_id_producto;

    -- Propaga hacia arriba a las recetas que contienen este producto.
    SELECT COALESCE(array_agg(DISTINCT ri.id_receta), ARRAY[]::BIGINT[])
    INTO v_padres
    FROM pro_receta_insumo ri
    JOIN pro_receta r ON r.id = ri.id_receta
    WHERE ri.id_producto_insumo = v_id_producto
      AND ri.estado = 1
      AND r.estado = 1
      AND ri.id_receta <> p_id_receta;

    FOREACH v_padre IN ARRAY v_padres LOOP
        PERFORM pro_recalcular_costo_receta(v_padre, p_profundidad + 1);
    END LOOP;
END;
$function$;