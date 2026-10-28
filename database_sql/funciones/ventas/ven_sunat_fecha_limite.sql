-- Último día para enviar el comprobante a SUNAT: fecha de emisión (Lima) + días
-- configurados por tipo en gen_configuracion_sunat (3 boleta / 7 factura si no hay
-- configuración). NULL para lo que no se envía (nota de venta).
DROP FUNCTION IF EXISTS ven_sunat_fecha_limite(
    p_tipo_comprobante SMALLINT,
    p_fecha_emision TIMESTAMPTZ,
    p_id_sucursal BIGINT
);
DROP FUNCTION IF EXISTS ven_sunat_fecha_limite(p_tipo SMALLINT, p_fecha TIMESTAMPTZ, p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_fecha_limite(
    p_tipo_comprobante SMALLINT,
    p_fecha_emision TIMESTAMPTZ,
    p_id_sucursal BIGINT
)
RETURNS DATE
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_dias SMALLINT;
BEGIN
    IF p_tipo_comprobante NOT IN (1, 2) THEN
        RETURN NULL;
    END IF;

    SELECT CASE
               WHEN p_tipo_comprobante = 1 THEN c.dias_limite_envio_boleta
               ELSE c.dias_limite_envio_factura
           END
    INTO v_dias
    FROM gen_sucursal s
    INNER JOIN gen_configuracion_sunat c
        ON c.id_empresa = s.id_empresa
       AND c.estado = 1
    WHERE s.id = p_id_sucursal;

    RETURN (p_fecha_emision AT TIME ZONE 'America/Lima')::DATE
        + COALESCE(v_dias, CASE WHEN p_tipo_comprobante = 1 THEN 3 ELSE 7 END);
END;
$function$;
