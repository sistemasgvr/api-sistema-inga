-- Un movimiento es de la sucursal cuando todos los almacenes de su detalle
-- pertenecen a ella. Sin sucursal (p_id_sucursal NULL) no se restringe.
DROP FUNCTION IF EXISTS alm_movimiento_de_sucursal(p_id_movimiento BIGINT, p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION alm_movimiento_de_sucursal(
    p_id_movimiento BIGINT,
    p_id_sucursal BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $function$
    SELECT p_id_sucursal IS NULL OR NOT EXISTS (
        SELECT 1
        FROM alm_movimiento_detalle d
        LEFT JOIN gen_almacen a ON a.id = d.id_almacen
        WHERE d.id_movimiento = p_id_movimiento
          AND a.id_sucursal IS DISTINCT FROM p_id_sucursal
    );
$function$;
