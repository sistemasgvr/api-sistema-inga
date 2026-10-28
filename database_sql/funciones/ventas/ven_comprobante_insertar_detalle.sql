-- Copia los platos vigentes del pedido al comprobante con sus datos tributarios.
-- Mismo redondeo por línea que ven_recalcular_pedido:
--   afecto_igv = TRUE  → el precio ya incluye IGV (base = subtotal / (1 + tasa));
--   afecto_igv = FALSE → el IGV se agrega encima (total = subtotal × (1 + tasa)).
-- Con tasa 0 la línea va como exonerada (catálogo SUNAT 07: 20); si no, gravada (10).
DROP FUNCTION IF EXISTS ven_comprobante_insertar_detalle(p_id_comprobante BIGINT, p_id_pedido BIGINT);
CREATE OR REPLACE FUNCTION ven_comprobante_insertar_detalle(
    p_id_comprobante BIGINT,
    p_id_pedido BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO ven_comprobante_detalle (
        id_comprobante,
        id_pedido_detalle,
        id_producto,
        descripcion,
        cantidad,
        unidad,
        precio_unitario,
        monto_total,
        unidad_sunat,
        tipo_afectacion_igv,
        tasa_igv,
        valor_unitario,
        precio_unitario_igv,
        monto_base_igv,
        monto_igv
    )
    SELECT
        p_id_comprobante,
        d.id,
        d.id_producto,
        p.nombre,
        x.cantidad,
        u.simbolo,
        d.precio_unitario,
        d.monto_subtotal,
        COALESCE(NULLIF(TRIM(u.codigo_sunat), ''), 'NIU'),
        CASE WHEN v.tasa_igv = 0 THEN '20' ELSE '10' END,
        v.tasa_igv,
        ROUND(x.base / x.cantidad, 10),
        ROUND(x.total / x.cantidad, 10),
        x.base,
        x.total - x.base
    FROM ven_pedido_detalle d
    INNER JOIN ven_pedido v ON v.id = d.id_pedido
    INNER JOIN pro_producto p ON p.id = d.id_producto
    INNER JOIN pro_unidad_medida u ON u.id = p.id_unidad_medida
    CROSS JOIN LATERAL (
        SELECT
            d.cantidad - d.cantidad_cancelada AS cantidad,
            CASE
                WHEN d.afecto_igv THEN ROUND(d.monto_subtotal / (1 + v.tasa_igv / 100), 2)
                ELSE d.monto_subtotal
            END AS base,
            CASE
                WHEN d.afecto_igv THEN d.monto_subtotal
                ELSE ROUND(d.monto_subtotal * (1 + v.tasa_igv / 100), 2)
            END AS total
    ) x
    WHERE d.id_pedido = p_id_pedido
      AND d.estado = 1
      AND d.tipo_linea <> 3
      AND d.cantidad > d.cantidad_cancelada
    ORDER BY d.id;
END;
$function$;
