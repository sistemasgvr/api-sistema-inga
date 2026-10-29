-- Empresas activas con token de APIsPERU configurado. El programador de SUNAT
-- recorre cada una por separado (cada empresa es un emisor distinto).
DROP FUNCTION IF EXISTS gen_listar_empresas_sunat_activas();
CREATE OR REPLACE FUNCTION gen_listar_empresas_sunat_activas()
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SELECT COALESCE(json_agg(
        json_build_object(
            'id', e.id,
            'ruc', e.ruc,
            'razon_social', e.razon_social
        ) ORDER BY e.id
    ), '[]'::JSON)
    INTO v_registros
    FROM gen_empresa e
    INNER JOIN gen_configuracion_sunat c
        ON c.id_empresa = e.id
       AND c.estado = 1
    WHERE e.estado = 1
      AND NULLIF(c.token_emision_cifrado, '') IS NOT NULL;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
