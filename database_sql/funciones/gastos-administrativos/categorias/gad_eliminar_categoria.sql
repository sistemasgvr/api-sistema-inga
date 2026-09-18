-- Doy de baja lógica una categoría de gasto (estado = 0).
--
-- No borro la fila: gad_gasto apunta a ella y perdería la clasificación del
-- histórico, que es justo lo que alimenta el reporte mensual y la rentabilidad
-- del dashboard.
--
-- Bloqueo la baja en dos casos:
--   - tiene gastos registrados → el histórico quedaría apuntando a una
--     categoría invisible y el reporte mostraría filas sin nombre
--   - tiene subcategorías activas → quedarían huérfanas, colgando de una rama
--     que ya no aparece en el árbol
CREATE OR REPLACE FUNCTION gad_eliminar_categoria(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_gastos INTEGER;
    v_hijas INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_gastos
    FROM gad_gasto WHERE id_categoria = p_id AND estado = 1;

    IF v_gastos > 0 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede dar de baja: la categoría tiene ' || v_gastos ||
                     ' gasto(s) registrado(s). Su histórico dejaría de verse en el reporte.'
        );
    END IF;

    SELECT COUNT(*) INTO v_hijas
    FROM gad_categoria WHERE id_categoria_padre = p_id AND estado = 1;

    IF v_hijas > 0 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede dar de baja: la categoría tiene ' || v_hijas ||
                     ' subcategoría(s) activa(s). Da de baja primero las subcategorías.'
        );
    END IF;

    UPDATE gad_categoria
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
