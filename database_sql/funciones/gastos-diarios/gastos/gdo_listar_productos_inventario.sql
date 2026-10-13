-- Productos del inventario que se pueden comprar desde las compras del día.
--
-- Son los que controlan stock y se reponen comprándolos (insumos crudos,
-- bebidas en lata). Quedan fuera los que se preparan con receta: su stock
-- entra por producción, no por compra (misma regla que alm_confirmar).
--
-- Incluyo los que tienen stock en cero y los que nunca tuvieron fila en
-- alm_producto_stock: un producto agotado es justo el que más hay que comprar.
--
-- Devuelvo también los almacenes activos, porque cada compra entra a uno, y
-- el stock de cada producto por almacén para mostrarlo al elegir.
-- Sin paginar: son pocos y el formulario los necesita todos a mano.
CREATE OR REPLACE FUNCTION gdo_listar_productos_inventario(
    p_buscar VARCHAR DEFAULT '',
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT json_build_object(
        'productos', COALESCE((
            SELECT json_agg(row_to_json(x) ORDER BY x.nombre)
            FROM (
                SELECT
                    pr.id,
                    pr.nombre,
                    pr.id_unidad_medida,
                    um.nombre AS nombre_unidad,
                    um.simbolo AS simbolo_unidad,
                    pr.id_almacen_stock,
                    COALESCE(st.stock_total, 0) AS stock_total,
                    COALESCE(st.stocks, '[]'::JSON) AS stocks,
                    -- Sugiere el precio: el costo promedio con que se viene comprando.
                    COALESCE(st.costo_promedio, 0) AS costo_referencial
                FROM pro_producto pr
                INNER JOIN pro_unidad_medida um ON um.id = pr.id_unidad_medida
                LEFT JOIN pro_tipo_producto tp ON tp.id = pr.tipo_producto
                LEFT JOIN LATERAL (
                    SELECT
                        SUM(s.stock_actual) AS stock_total,
                        MAX(s.costo_promedio) AS costo_promedio,
                        json_agg(json_build_object(
                            'id_almacen', s.id_almacen,
                            'stock_actual', s.stock_actual,
                            'stock_disponible', s.stock_actual - s.stock_reservado
                        ) ORDER BY s.id_almacen) AS stocks
                    FROM alm_producto_stock s
                    INNER JOIN gen_almacen a ON a.id = s.id_almacen AND a.estado = 1
                    WHERE s.id_producto = pr.id AND s.estado = 1
                ) st ON TRUE
                WHERE pr.estado = 1
                  AND pr.controla_stock
                  AND NOT COALESCE(tp.requiere_receta AND NOT tp.permite_stock_inicial, FALSE)
                  AND (COALESCE(p_buscar, '') = ''
                       OR pr.nombre ILIKE '%' || p_buscar || '%')
            ) x
        ), '[]'::JSON),
        'almacenes', COALESCE((
            SELECT json_agg(json_build_object(
                'id', a.id,
                'nombre', a.nombre,
                'tipo_almacen', a.tipo_almacen,
                'es_principal', a.es_principal
            ) ORDER BY a.es_principal DESC, a.tipo_almacen, a.id)
            FROM gen_almacen a
            WHERE a.estado = 1
              AND (p_id_sucursal IS NULL OR a.id_sucursal = p_id_sucursal)
        ), '[]'::JSON)
    );
$function$;
