-- Costo unitario de un producto, para valorar recetas.

CREATE OR REPLACE FUNCTION pro_costo_unitario_insumo(p_id_producto BIGINT)
RETURNS NUMERIC(14, 4)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_costo NUMERIC(14, 4);
    v_id_almacen_stock BIGINT;
BEGIN
    IF p_id_producto IS NULL THEN
        RETURN 0;
    END IF;

    -- Plato con receta vigente: vale su costo de receta.
    IF EXISTS (
        SELECT 1 FROM pro_receta r
        WHERE r.id_producto = p_id_producto AND r.estado = 1 AND r.vigente
    ) THEN
        SELECT COALESCE(costo_receta_calculado, 0) INTO v_costo
        FROM pro_producto WHERE id = p_id_producto;
        RETURN v_costo;
    END IF;

    -- Insumo crudo: promedio ponderado del almacén donde está almacenado.
    SELECT id_almacen_stock INTO v_id_almacen_stock
    FROM pro_producto WHERE id = p_id_producto;

    SELECT COALESCE(s.costo_promedio, 0) INTO v_costo
    FROM alm_producto_stock s
    WHERE s.id_producto = p_id_producto
      AND s.estado = 1
      AND s.id_almacen = v_id_almacen_stock
    LIMIT 1;

    RETURN COALESCE(v_costo, 0);
END;
$function$;