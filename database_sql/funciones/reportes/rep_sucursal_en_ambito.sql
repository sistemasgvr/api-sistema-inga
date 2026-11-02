-- ¿La sucursal entra en el ámbito del reporte? Sin empresa no se restringe. Una fila
-- sin sucursal (datos anteriores a multiempresa) solo cuenta si hay una sola empresa
-- activa, porque no se sabe a qué empresa pertenece.
DROP FUNCTION IF EXISTS rep_sucursal_en_ambito(
    p_id_sucursal_fila BIGINT,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_sucursal_en_ambito(
    p_id_sucursal_fila BIGINT,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $function$
    SELECT CASE
        WHEN p_id_sucursal_fila IS NULL THEN
            p_id_empresa IS NULL
            OR (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1
        ELSE
            (p_id_sucursal IS NULL OR p_id_sucursal_fila = p_id_sucursal)
            AND (
                p_id_empresa IS NULL
                OR EXISTS (
                    SELECT 1 FROM gen_sucursal s
                    WHERE s.id = p_id_sucursal_fila AND s.id_empresa = p_id_empresa
                )
            )
    END;
$function$;
