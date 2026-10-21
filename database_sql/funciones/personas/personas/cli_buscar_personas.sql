DROP FUNCTION IF EXISTS cli_buscar_personas(
    p_busqueda VARCHAR,
    p_rol VARCHAR,
    p_limite INTEGER
);
CREATE OR REPLACE FUNCTION cli_buscar_personas(
    p_busqueda VARCHAR DEFAULT '',
    p_rol VARCHAR DEFAULT NULL,
    p_limite INTEGER DEFAULT 15
)
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
            p.tipo_persona,
            p.tipo_documento,
            ld.nombre AS tipo_documento_nombre,
            p.num_documento,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' ||
                            COALESCE(p.apellido_paterno, '') || ' ' ||
                            COALESCE(p.apellido_materno, '')), ''),
                p.razon_social
            ) AS nombre_completo,
            p.telefono,
            p.direccion,
            p.es_cliente,
            p.es_proveedor,
            p.id_convenio,
            c.nombre AS nombre_convenio,
            c.limite_credito,
            -- Saldo para avisar en el cobro si el cliente ya pasó su límite de crédito.
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
            ), 0) AS saldo_credito
        FROM cli_persona p
        LEFT JOIN cli_convenio c ON p.id_convenio = c.id
        LEFT JOIN gen_lista_opcion ld ON ld.valor_entero = p.tipo_documento
            AND ld.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'DOCUMENTO_TIPO')
        WHERE p.estado = 1
          AND (
              p_rol IS NULL
              OR (p_rol = 'clientes' AND p.es_cliente = TRUE)
              OR (p_rol = 'proveedores' AND p.es_proveedor = TRUE)
          )
          AND (
              p_busqueda = ''
              OR COALESCE(p.num_documento, '') LIKE '%' || p_busqueda || '%'
              OR LOWER(COALESCE(p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(
                  TRIM(COALESCE(p.nombres, '') || ' ' ||
                       COALESCE(p.apellido_paterno, '') || ' ' ||
                       COALESCE(p.apellido_materno, ''))
              ) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY
            -- Primero lo que empieza igual a lo tecleado.
            CASE WHEN COALESCE(p.num_documento, '') LIKE p_busqueda || '%' THEN 0 ELSE 1 END,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) ASC
        LIMIT LEAST(COALESCE(p_limite, 15), 50)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
