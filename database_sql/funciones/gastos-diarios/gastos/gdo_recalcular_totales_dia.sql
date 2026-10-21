-- Recalcula los totales denormalizados de un día a partir de sus líneas vigentes.
-- forma_pago: 1 efectivo, 2 Yape, 3 crédito.
DROP FUNCTION IF EXISTS gdo_recalcular_totales_dia(p_id_gasto_dia BIGINT);
CREATE OR REPLACE FUNCTION gdo_recalcular_totales_dia(p_id_gasto_dia BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE gdo_gasto_dia d
    SET
        total_efectivo = COALESCE(t.efectivo, 0),
        total_yape = COALESCE(t.yape, 0),
        total_credito = COALESCE(t.credito, 0),
        total_general = COALESCE(t.efectivo, 0) + COALESCE(t.yape, 0) + COALESCE(t.credito, 0)
    FROM (
        SELECT
            SUM(det.subtotal) FILTER (WHERE det.forma_pago = 1) AS efectivo,
            SUM(det.subtotal) FILTER (WHERE det.forma_pago = 2) AS yape,
            SUM(det.subtotal) FILTER (WHERE det.forma_pago = 3) AS credito
        FROM gdo_gasto_detalle det
        WHERE det.id_gasto_dia = p_id_gasto_dia AND det.estado = 1
    ) t
    WHERE d.id = p_id_gasto_dia;
END;
$function$;
