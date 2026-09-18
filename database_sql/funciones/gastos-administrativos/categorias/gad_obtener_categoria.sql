-- Traigo una categoría de gasto por ID.
-- Crear y actualizar terminan llamando acá para devolver siempre el mismo shape.
CREATE OR REPLACE FUNCTION gad_obtener_categoria(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(x) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.id_categoria_padre,
            p.nombre AS nombre_categoria_padre,
            c.codigo,
            c.nombre,
            c.tipo_gasto,
            CASE c.tipo_gasto WHEN 1 THEN 'Fijo' ELSE 'Variable' END AS tipo_gasto_nombre,
            c.orden,
            c.estado,
            (
                SELECT COUNT(*)
                FROM gad_gasto g
                WHERE g.id_categoria = c.id AND g.estado = 1
            ) AS gastos_registrados,
            (
                SELECT COUNT(*)
                FROM gad_categoria h
                WHERE h.id_categoria_padre = c.id AND h.estado = 1
            ) AS subcategorias_activas,
            c.fecha_creacion,
            c.fecha_modificacion
        FROM gad_categoria c
        LEFT JOIN gad_categoria p ON c.id_categoria_padre = p.id
        WHERE c.id = p_id
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
