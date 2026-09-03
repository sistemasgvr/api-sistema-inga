CREATE OR REPLACE FUNCTION pro_listar_unidades_medida()
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_unidades JSON;
    v_conversiones JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_unidades
    FROM (
        SELECT id, codigo, codigo_sunat, nombre, simbolo, es_fraccionable
        FROM pro_unidad_medida
        WHERE estado = 1
        ORDER BY nombre ASC
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_conversiones
    FROM (
        SELECT 
            uc.id,
            uc.id_unidad_origen,
            uo.simbolo AS simbolo_origen,
            uc.id_unidad_destino,
            ud.simbolo AS simbolo_destino,
            uc.factor
        FROM pro_unidad_conversion uc
        JOIN pro_unidad_medida uo ON uc.id_unidad_origen = uo.id
        JOIN pro_unidad_medida ud ON uc.id_unidad_destino = ud.id
        WHERE uc.estado = 1
    ) t;

    RETURN json_build_object(
        'unidades', v_unidades,
        'conversiones', v_conversiones
    );
END;
$function$;