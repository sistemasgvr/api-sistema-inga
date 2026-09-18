-- Buscador rápido de personas, pensado para los autocompletar de otras pantallas.
--
-- Existe aparte de cli_listar_personas porque resuelve un problema distinto:
--   - cli_listar_personas alimenta la tabla del maestro: pagina, cuenta totales
--     y trae la ficha completa. Es pesada y no la quiero corriendo en cada tecla.
--   - esta devuelve pocas columnas y como máximo 15 filas, para que el usuario
--     escriba y vea sugerencias al instante.
--
-- Los requerimientos la piden en dos sitios:
--   M07 → "buscador de proveedor" en el alta de compra
--   M12 → "buscador de persona por nombre o documento" en el cobro a crédito
-- Por eso el parámetro p_rol: cada pantalla pide solo lo suyo y no se arriesga a
-- que el cajero elija por error a un proveedor como cliente a crédito.
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
            p.es_cliente,
            p.es_proveedor,
            p.id_convenio,
            c.nombre AS nombre_convenio,
            c.limite_credito,
            -- Mando el saldo para que la pantalla de cobro pueda avisar al
            -- cajero si el cliente ya se pasó de su límite de crédito.
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
              OR p.num_documento LIKE '%' || p_busqueda || '%'
              OR LOWER(COALESCE(p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(
                  TRIM(COALESCE(p.nombres, '') || ' ' ||
                       COALESCE(p.apellido_paterno, '') || ' ' ||
                       COALESCE(p.apellido_materno, ''))
              ) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY
            -- Primero lo que empieza igual a lo tecleado: si escribo "456",
            -- el documento 45612345 sale antes que el 12345645.
            CASE WHEN p.num_documento LIKE p_busqueda || '%' THEN 0 ELSE 1 END,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) ASC
        LIMIT LEAST(COALESCE(p_limite, 15), 50)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
