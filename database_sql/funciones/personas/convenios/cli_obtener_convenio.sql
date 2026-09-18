-- Traigo un convenio por ID con los mismos campos que el listado.
--
-- Las funciones de crear y actualizar terminan llamando a esta, así el front
-- recibe siempre el registro completo y con el mismo formato, sin importar
-- por cuál de las tres operaciones haya pasado.
CREATE OR REPLACE FUNCTION cli_obtener_convenio(p_id BIGINT)
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
            c.codigo,
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
            ) AS personas_asignadas,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM cli_convenio c
        INNER JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN auth_usuario uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um ON c.id_usuario_modificacion = um.id
        WHERE c.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
