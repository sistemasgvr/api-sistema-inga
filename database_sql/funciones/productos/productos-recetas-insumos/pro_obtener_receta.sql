CREATE OR REPLACE FUNCTION pro_obtener_receta(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            r.id,
            r.id_producto,
            p.nombre AS nombre_producto,
            r.version,
            r.nombre AS nombre_receta,
            r.rendimiento_porciones,
            r.vigente,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            (
                SELECT COALESCE(json_agg(row_to_json(ri_t)), '[]'::JSON)
                FROM (
                    SELECT
                        ri.id,
                        ri.id_receta,
                        ri.id_producto_insumo,
                        pi.nombre AS nombre_insumo,
                        pi.tipo_producto,
                        ri.cantidad,
                        ri.id_unidad_medida,
                        um.simbolo AS simbolo_unidad,
                        ri.porcentaje_merma,
                        ri.es_opcional,
                        ri.grupo_sustitucion,
                        ri.orden
                    FROM pro_receta_insumo ri
                    INNER JOIN pro_producto pi ON ri.id_producto_insumo = pi.id
                    INNER JOIN pro_unidad_medida um ON ri.id_unidad_medida = um.id
                    WHERE ri.id_receta = r.id AND ri.estado = 1
                    ORDER BY ri.orden ASC, ri.id ASC
                ) ri_t
            ) AS insumos
        FROM pro_receta r
        INNER JOIN pro_producto p ON r.id_producto = p.id
        WHERE r.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
