-- Distrito por su código de ubigeo (INEI), con provincia y departamento. Lo usa la
-- consulta de RUC para proponer el domicilio fiscal. registro NULL si no existe.
DROP FUNCTION IF EXISTS gen_obtener_distrito_por_ubigeo(p_ubigeo VARCHAR);
CREATE OR REPLACE FUNCTION gen_obtener_distrito_por_ubigeo(p_ubigeo VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'id', d.id,
        'ubigeo', d.codigo_ubigeo,
        'distrito', d.nombre,
        'provincia', p.nombre,
        'departamento', dp.nombre
    )
    INTO v_registro
    FROM gen_distrito d
    INNER JOIN gen_provincia p ON p.id = d.id_provincia
    INNER JOIN gen_departamento dp ON dp.id = p.id_departamento
    WHERE d.codigo_ubigeo = TRIM(p_ubigeo)
      AND d.estado = 1
    LIMIT 1;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
