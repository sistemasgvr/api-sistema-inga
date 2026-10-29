-- Series iniciales de numeración de una empresa: B001 (boleta), F001 (factura) y
-- NV01 (nota de venta). Se crean una sola vez por empresa; la numeración es
-- compartida entre todas sus sucursales. Re-ejecutable.
DROP FUNCTION IF EXISTS gen_crear_series_empresa(p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION gen_crear_series_empresa(p_id_empresa BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_creadas INTEGER := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM gen_empresa WHERE id = p_id_empresa) THEN
        RETURN json_build_object('error', 'La empresa no existe', 'creadas', 0);
    END IF;

    INSERT INTO gen_correlativo (id_empresa, tipo_documento, serie, ultimo_numero, longitud)
    SELECT p_id_empresa, x.tipo, x.serie, 0, 8
    FROM (VALUES (1, 'B001'), (2, 'F001'), (3, 'NV01')) AS x(tipo, serie)
    WHERE NOT EXISTS (
        SELECT 1
        FROM gen_correlativo c
        WHERE c.id_empresa = p_id_empresa
          AND c.tipo_documento = x.tipo
          AND c.serie = x.serie
    );

    GET DIAGNOSTICS v_creadas = ROW_COUNT;

    RETURN json_build_object('creadas', v_creadas);
END;
$function$;
