DO $$
DECLARE
    v_receta RECORD;
    v_total INTEGER := 0;
BEGIN
    FOR v_receta IN
        SELECT r.id
        FROM pro_receta r
        WHERE r.estado = 1 AND r.vigente
    LOOP
        PERFORM pro_recalcular_costo_receta(v_receta.id);
        v_total := v_total + 1;
    END LOOP;

    RAISE NOTICE 'Recetas recalculadas: %', v_total;
END;
$$;