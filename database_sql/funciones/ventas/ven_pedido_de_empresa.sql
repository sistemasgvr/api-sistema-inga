-- Un pedido es de la empresa dueña de su sucursal. Sin empresa (p_id_empresa NULL)
-- no se restringe.
DROP FUNCTION IF EXISTS ven_pedido_de_empresa(p_id_pedido BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION ven_pedido_de_empresa(
    p_id_pedido BIGINT,
    p_id_empresa BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $function$
    SELECT p_id_empresa IS NULL OR EXISTS (
        SELECT 1
        FROM ven_pedido p
        JOIN gen_sucursal s ON s.id = p.id_sucursal
        WHERE p.id = p_id_pedido
          AND s.id_empresa = p_id_empresa
    );
$function$;
