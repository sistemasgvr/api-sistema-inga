-- Se elimina la firma anterior (solo p_busqueda): con otra firma, CREATE OR
-- REPLACE crea una sobrecarga en vez de reemplazar y la vieja queda viva.
DROP FUNCTION IF EXISTS pro_listar_insumos_procesados(VARCHAR);
DROP FUNCTION IF EXISTS pro_listar_insumos_procesados(
    VARCHAR, BIGINT, BIGINT, BIGINT
);

CREATE OR REPLACE FUNCTION pro_listar_insumos_procesados(
    p_busqueda VARCHAR DEFAULT '',
    p_id_categoria BIGINT DEFAULT NULL,
    p_id_subcategoria BIGINT DEFAULT NULL,
    p_id_tipo_producto BIGINT DEFAULT NULL
)
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
            p.id,
            p.codigo_interno,
            p.nombre,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            um.simbolo AS simbolo_unidad,
            p.precio_venta,
            p.tipo_producto,
            tp.nombre AS nombre_tipo_producto,
            sc.id_categoria,
            p.id_subcategoria,
            -- Distingue un sub-plato de un insumo crudo en la UI: el sub-plato
            -- tiene su propio desglose y su propio costo ya calculado.
            EXISTS (
                SELECT 1 FROM pro_receta r
                WHERE r.id_producto = p.id AND r.estado = 1 AND r.vigente
            ) AS tiene_receta,
            -- Un sub-plato con grupos de sustitución no puede anticiparse:
            -- prod_preparar lo rechaza y obliga a prepararlo por pedido.
            -- La UI avisa antes de agregarlo.
            EXISTS (
                SELECT 1 FROM pro_receta r
                JOIN pro_receta_insumo ri ON ri.id_receta = r.id AND ri.estado = 1
                WHERE r.id_producto = p.id AND r.estado = 1 AND r.vigente
                  AND ri.grupo_sustitucion IS NOT NULL
            ) AS tiene_grupos_sustitucion,
            COALESCE(p.costo_receta_calculado, 0) AS costo_receta_calculado
        FROM pro_producto p
        INNER JOIN pro_unidad_medida um ON p.id_unidad_medida = um.id
        INNER JOIN pro_tipo_producto tp ON tp.id = p.tipo_producto
        LEFT JOIN pro_subcategoria sc ON sc.id = p.id_subcategoria
        WHERE p.estado = 1
          AND p.controla_stock
          AND (p_id_tipo_producto IS NULL OR p.tipo_producto = p_id_tipo_producto)
          AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
          AND (p_id_subcategoria IS NULL OR p.id_subcategoria = p_id_subcategoria)
          AND (
              p_busqueda = ''
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY p.nombre ASC
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;