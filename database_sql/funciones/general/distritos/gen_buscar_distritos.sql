-- Distritos con su ubigeo, provincia y departamento para elegir el domicilio fiscal.
DROP FUNCTION IF EXISTS gen_buscar_distritos(p_busqueda VARCHAR, p_limite INTEGER);
CREATE OR REPLACE FUNCTION gen_buscar_distritos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 50
)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_busqueda VARCHAR := TRIM(COALESCE(p_busqueda, ''));
    v_registros JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            d.id,
            d.codigo_ubigeo,
            d.nombre AS distrito,
            p.nombre AS provincia,
            dp.nombre AS departamento
        FROM gen_distrito d
        INNER JOIN gen_provincia p ON p.id = d.id_provincia
        INNER JOIN gen_departamento dp ON dp.id = p.id_departamento
        WHERE d.estado = 1
          AND (
              v_busqueda = ''
              OR LOWER(d.nombre) LIKE LOWER('%' || v_busqueda || '%')
              OR LOWER(p.nombre) LIKE LOWER('%' || v_busqueda || '%')
              OR d.codigo_ubigeo LIKE v_busqueda || '%'
          )
        ORDER BY dp.nombre, p.nombre, d.nombre
        LIMIT p_limite
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
