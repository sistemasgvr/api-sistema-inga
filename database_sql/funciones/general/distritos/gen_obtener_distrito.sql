-- Un distrito con su ubigeo, provincia y departamento.
DROP FUNCTION IF EXISTS gen_obtener_distrito(p_id BIGINT);
CREATE OR REPLACE FUNCTION gen_obtener_distrito(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT json_build_object(
        'id', d.id,
        'codigo_ubigeo', d.codigo_ubigeo,
        'distrito', d.nombre,
        'provincia', p.nombre,
        'departamento', dp.nombre
    )
    INTO v_registro
    FROM gen_distrito d
    INNER JOIN gen_provincia p ON p.id = d.id_provincia
    INNER JOIN gen_departamento dp ON dp.id = p.id_departamento
    WHERE d.id = p_id;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
