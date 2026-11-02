-- Un turno es de la sucursal de su caja. Sin sucursal (p_id_sucursal NULL)
-- no se restringe.
DROP FUNCTION IF EXISTS caj_turno_de_sucursal(p_id_turno BIGINT, p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION caj_turno_de_sucursal(
    p_id_turno BIGINT,
    p_id_sucursal BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $function$
    SELECT p_id_sucursal IS NULL OR EXISTS (
        SELECT 1
        FROM caj_turno t
        JOIN caj_caja c ON c.id = t.id_caja
        WHERE t.id = p_id_turno
          AND c.id_sucursal = p_id_sucursal
    );
$function$;
