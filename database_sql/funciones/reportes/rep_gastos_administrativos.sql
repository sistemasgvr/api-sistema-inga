-- Gastos administrativos del período. Un gasto sin sucursal es de toda la empresa
-- (su categoría) y entra en cualquier filtro de sucursal.
DROP FUNCTION IF EXISTS rep_gastos_administrativos(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_gastos_administrativos(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    WITH medios AS (
        SELECT o.valor_entero AS medio_pago, o.nombre
        FROM gen_lista_opcion o
        JOIN gen_lista l ON l.id = o.id_lista
        WHERE l.codigo = 'MEDIO_PAGO'
    )
    SELECT COALESCE(json_agg(x ORDER BY x.fecha DESC, x.id DESC), '[]'::JSON)
    FROM (
        SELECT
            g.id::INT AS id,
            to_char(g.fecha_gasto, 'YYYY-MM-DD') AS fecha,
            COALESCE(cp.nombre, c.nombre) AS categoria,
            CASE WHEN cp.id IS NOT NULL THEN c.nombre END AS subcategoria,
            c.tipo_gasto::INT AS tipo_gasto,
            g.concepto,
            g.medio_pago::INT AS medio_pago,
            COALESCE(m.nombre, g.medio_pago::TEXT) AS medio,
            g.num_comprobante,
            g.monto::FLOAT8 AS monto
        FROM gad_gasto g
        JOIN gad_categoria c ON c.id = g.id_categoria
        LEFT JOIN gad_categoria cp ON cp.id = c.id_categoria_padre
        LEFT JOIN medios m ON m.medio_pago = g.medio_pago
        WHERE g.estado = 1
          AND g.fecha_gasto BETWEEN p_fecha_desde AND p_fecha_hasta
          AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
          AND (p_id_sucursal IS NULL OR g.id_sucursal IS NULL OR g.id_sucursal = p_id_sucursal)
    ) x;
$function$;
