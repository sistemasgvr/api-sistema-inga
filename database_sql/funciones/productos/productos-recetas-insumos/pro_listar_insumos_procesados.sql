CREATE OR REPLACE FUNCTION pro_listar_insumos_procesados(p_busqueda VARCHAR DEFAULT '')
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            p.id,
            p.codigo_interno,
            p.nombre,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            um.simbolo AS simbolo_unidad,
            p.precio_venta
        FROM pro_producto p
        INNER JOIN pro_unidad_medida um ON p.id_unidad_medida = um.id
        WHERE p.estado = 1
          AND p.tipo_producto = 2 
          AND (
              p_busqueda = ''
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY p.nombre ASC
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;