CREATE OR REPLACE FUNCTION gen_obtener_estacion(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            e.id,
            e.id_sucursal,
            s.nombre AS nombre_sucursal,
            e.codigo,
            e.nombre,
            e.tipo_estacion,
            lo.nombre AS tipo_estacion_nombre,
            e.impresora_nombre,
            e.impresora_ip,
            e.usa_kds,
            e.estado,
            e.fecha_creacion,
            e.fecha_modificacion,
            e.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            e.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM gen_estacion e
        INNER JOIN gen_sucursal s ON e.id_sucursal = s.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = e.tipo_estacion 
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'ESTACION_TIPO')
        LEFT JOIN auth_usuario uc ON e.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um ON e.id_usuario_modificacion = um.id
        WHERE e.id = p_id AND e.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;