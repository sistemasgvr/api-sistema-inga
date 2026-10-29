DROP FUNCTION IF EXISTS cli_obtener_convenio(p_id BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION cli_obtener_convenio(p_id BIGINT, p_id_empresa BIGINT DEFAULT NULL)
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
            c.id,
            c.nombre,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            cp.dias_credito,
            c.limite_credito,
            c.corte_quincenal,
            c.estado,
            (
                SELECT COUNT(*)
                FROM cli_persona p
                WHERE p.id_convenio = c.id AND p.estado = 1
                  AND (p_id_empresa IS NULL OR p.id_empresa = p_id_empresa)
            ) AS personas_asignadas,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM cli_convenio c
        INNER JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN auth_usuario_datos uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario_datos um ON c.id_usuario_modificacion = um.id
        WHERE c.id = p_id
          AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;