-- Foto del stock al momento de la consulta (sin rango de fechas), de los almacenes
-- de la empresa y (opcional) sucursal.
DROP FUNCTION IF EXISTS rep_stock(
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_stock(
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT COALESCE(json_agg(x ORDER BY x.almacen, x.producto), '[]'::JSON)
    FROM (
        SELECT
            s.id::INT AS id,
            a.nombre AS almacen,
            p.nombre AS producto,
            COALESCE(u.simbolo, u.nombre) AS unidad,
            s.stock_actual::FLOAT8 AS stock_actual,
            s.stock_reservado::FLOAT8 AS stock_reservado,
            s.stock_minimo::FLOAT8 AS stock_minimo,
            s.costo_promedio::FLOAT8 AS costo_promedio,
            round(s.stock_actual * s.costo_promedio, 2)::FLOAT8 AS valorizado,
            (p.controla_stock AND s.stock_minimo > 0 AND s.stock_actual <= s.stock_minimo) AS bajo_minimo
        FROM alm_producto_stock s
        JOIN gen_almacen a ON a.id = s.id_almacen
        JOIN pro_producto p ON p.id = s.id_producto
        LEFT JOIN pro_unidad_medida u ON u.id = p.id_unidad_medida
        WHERE s.estado = 1
          AND p.estado = 1
          AND a.estado = 1
          AND rep_sucursal_en_ambito(a.id_sucursal, p_id_empresa, p_id_sucursal)
    ) x;
$function$;
