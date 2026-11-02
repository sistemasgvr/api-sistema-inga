-- Ventas del período para los reportes: pedidos cobrados (estado_pedido 4) y vigentes,
-- fechados por su cobro en Lima, de la empresa y (opcional) sucursal indicadas.
DROP FUNCTION IF EXISTS rep_ventas_periodo(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_ventas_periodo(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    id_sucursal BIGINT,
    id_mozo BIGINT,
    id_mesa BIGINT,
    codigo VARCHAR,
    tipo_pedido SMALLINT,
    num_comensales INTEGER,
    monto_total NUMERIC,
    monto_igv NUMERIC,
    monto_descuento NUMERIC,
    tasa_igv NUMERIC,
    fecha_cierre TIMESTAMPTZ,
    fecha_lima TIMESTAMP
)
LANGUAGE sql
STABLE
AS $function$
    SELECT
        p.id, p.id_sucursal, p.id_mozo, p.id_mesa, p.codigo, p.tipo_pedido,
        p.num_comensales, p.monto_total, p.monto_igv, p.monto_descuento, p.tasa_igv,
        p.fecha_cierre,
        p.fecha_cierre AT TIME ZONE 'America/Lima'
    FROM ven_pedido p
    WHERE p.estado = 1
      AND p.estado_pedido = 4
      AND (p.fecha_cierre AT TIME ZONE 'America/Lima')::DATE BETWEEN p_fecha_desde AND p_fecha_hasta
      AND (p_id_sucursal IS NULL OR p.id_sucursal = p_id_sucursal)
      AND (
          p_id_empresa IS NULL
          OR p.id_sucursal IN (SELECT s.id FROM gen_sucursal s WHERE s.id_empresa = p_id_empresa)
      );
$function$;
