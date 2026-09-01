CREATE OR REPLACE FUNCTION pro_listar_recetas_producto(p_id_producto BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            r.id,
            r.id_producto,
            r.version,
            r.nombre,
            r.rendimiento_porciones,
            r.vigente,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER 
                FROM pro_receta_insumo ri 
                WHERE ri.id_receta = r.id AND ri.estado = 1
            ) AS total_insumos
        FROM pro_receta r
        WHERE r.id_producto = p_id_producto
        ORDER BY r.version DESC
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;