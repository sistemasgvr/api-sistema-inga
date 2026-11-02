-- Movimientos de inventario confirmados del período, por tipo y motivo.
DROP FUNCTION IF EXISTS rep_movimientos_inventario(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_movimientos_inventario(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT COALESCE(json_agg(x ORDER BY x.tipo_movimiento, x.motivo), '[]'::JSON)
    FROM (
        SELECT
            k.tipo_movimiento,
            k.motivo,
            COUNT(DISTINCT k.id_movimiento)::INT AS movimientos,
            COALESCE(SUM(k.entrada * k.costo_unitario), 0)::FLOAT8 AS valor_entradas,
            COALESCE(SUM(k.salida * k.costo_unitario), 0)::FLOAT8 AS valor_salidas
        FROM vw_alm_kardex k
        JOIN gen_almacen a ON a.id = k.id_almacen
        WHERE (COALESCE(k.fecha_confirmacion, k.fecha_movimiento) AT TIME ZONE 'America/Lima')::DATE
                BETWEEN p_fecha_desde AND p_fecha_hasta
          AND rep_sucursal_en_ambito(a.id_sucursal, p_id_empresa, p_id_sucursal)
        GROUP BY k.tipo_movimiento, k.motivo
    ) x;
$function$;
