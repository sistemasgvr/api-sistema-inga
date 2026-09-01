CREATE OR REPLACE FUNCTION gen_obtener_almacen(p_id BIGINT)
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
            a.id,
            a.id_sucursal,
            s.nombre AS nombre_sucursal,
            a.codigo,
            a.nombre,
            a.descripcion,
            a.tipo_almacen,
            lo.nombre AS tipo_almacen_nombre,
            a.es_principal,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion,
            a.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            a.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM gen_almacen a
        INNER JOIN gen_sucursal s ON a.id_sucursal = s.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = a.tipo_almacen 
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'ALMACEN_TIPO')
        LEFT JOIN auth_usuario uc ON a.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um ON a.id_usuario_modificacion = um.id
        WHERE a.id = p_id AND a.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
