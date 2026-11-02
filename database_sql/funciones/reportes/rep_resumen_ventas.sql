-- Totales de ventas del período.
DROP FUNCTION IF EXISTS rep_resumen_ventas(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_resumen_ventas(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    WITH ventas AS (
        SELECT * FROM rep_ventas_periodo(p_fecha_desde, p_fecha_hasta, p_id_empresa, p_id_sucursal)
    )
    SELECT json_build_object(
        'cantidad', COUNT(*)::INT,
        'total', COALESCE(SUM(monto_total), 0)::FLOAT8,
        'igv', COALESCE(SUM(monto_igv), 0)::FLOAT8,
        'descuentos', COALESCE(SUM(monto_descuento), 0)::FLOAT8,
        'comensales', COALESCE(SUM(num_comensales), 0)::INT
    )
    FROM ventas;
$function$;
