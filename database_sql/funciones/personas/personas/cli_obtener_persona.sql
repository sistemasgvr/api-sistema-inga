-- Traigo una persona por ID con su saldo_credito actual. No filtra por estado:
-- la ficha y la reactivación necesitan leer personas inactivas.
DROP FUNCTION IF EXISTS cli_obtener_persona(p_id BIGINT);
CREATE OR REPLACE FUNCTION cli_obtener_persona(p_id BIGINT)
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
            p.id,
            p.tipo_persona,
            lp.nombre AS tipo_persona_nombre,
            p.tipo_documento,
            ld.nombre AS tipo_documento_nombre,
            p.num_documento,
            p.razon_social,
            p.nombres,
            p.apellido_paterno,
            p.apellido_materno,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' ||
                            COALESCE(p.apellido_paterno, '') || ' ' ||
                            COALESCE(p.apellido_materno, '')), ''),
                p.razon_social
            ) AS nombre_completo,
            p.direccion,
            p.id_distrito,
            d.nombre AS nombre_distrito,
            p.telefono,
            p.email,
            p.es_cliente,
            p.es_proveedor,
            p.id_convenio,
            c.nombre AS nombre_convenio,
            c.limite_credito,
            -- Tipo 1 cargo suma, 2 abono resta; el ELSE cubre el ajuste (3), que ya trae su signo.
            COALESCE((
                SELECT SUM(
                    CASE
                        WHEN m.tipo_movimiento = 1 THEN m.monto
                        WHEN m.tipo_movimiento = 2 THEN -m.monto
                        ELSE m.monto
                    END
                )
                FROM cxc_movimiento m
                WHERE m.id_persona = p.id AND m.estado = 1
            ), 0) AS saldo_credito,
            p.estado,
            p.fecha_creacion,
            p.fecha_modificacion,
            p.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            p.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM cli_persona p
        LEFT JOIN cli_convenio c ON p.id_convenio = c.id
        LEFT JOIN gen_distrito d ON p.id_distrito = d.id
        LEFT JOIN gen_lista_opcion lp ON lp.valor_entero = p.tipo_persona
            AND lp.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'PERSONA_TIPO')
        LEFT JOIN gen_lista_opcion ld ON ld.valor_entero = p.tipo_documento
            AND ld.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'DOCUMENTO_TIPO')
        LEFT JOIN auth_usuario_datos uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario_datos um ON p.id_usuario_modificacion = um.id
        WHERE p.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
