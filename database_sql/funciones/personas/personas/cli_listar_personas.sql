-- Listo clientes y proveedores desde cli_persona.
--
-- Una misma fila puede ser cliente, proveedor o las dos cosas (es_cliente /
-- es_proveedor). Por eso el filtro p_rol no es un campo de la tabla sino un
-- atajo para la pantalla: 'clientes', 'proveedores' o NULL para ver todo.
--
-- Armo "nombre_completo" acá, en la base, y no en el front. El motivo: una
-- persona natural se muestra como "Nombres Apellidos" y una jurídica como su
-- razón social. Si lo resolviera en el front tendría que repetir ese if en la
-- tabla, en el buscador del cobro a crédito (M12) y en el de compras (M07).
CREATE OR REPLACE FUNCTION cli_listar_personas(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_rol VARCHAR DEFAULT NULL,
    p_id_convenio BIGINT DEFAULT NULL,
    p_estado INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_cant_total BIGINT;
    v_cant_activos BIGINT;
    v_cant_inactivos BIGINT;
    v_cant_clientes BIGINT;
    v_cant_proveedores BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Resumen para las tarjetas de la pantalla. Cuento sobre el universo
    -- completo (sin filtro de estado ni de rol) para que los números no bailen
    -- cada vez que el usuario cambia un filtro.
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE p.estado = 1),
        COUNT(*) FILTER (WHERE p.estado = 0),
        COUNT(*) FILTER (WHERE p.es_cliente = TRUE AND p.estado = 1),
        COUNT(*) FILTER (WHERE p.es_proveedor = TRUE AND p.estado = 1)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos, v_cant_clientes, v_cant_proveedores
    FROM cli_persona p;

    SELECT COUNT(*) INTO v_total
    FROM cli_persona p
    WHERE (p_estado IS NULL OR p.estado = p_estado)
      AND (p_id_convenio IS NULL OR p.id_convenio = p_id_convenio)
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
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
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
            -- Nombre listo para mostrar, sin que el front tenga que decidir.
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
        LEFT JOIN auth_usuario uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um ON p.id_usuario_modificacion = um.id
        WHERE (p_estado IS NULL OR p.estado = p_estado)
          AND (p_id_convenio IS NULL OR p.id_convenio = p_id_convenio)
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
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total', v_cant_total,
            'activos', v_cant_activos,
            'inactivos', v_cant_inactivos,
            'clientes', v_cant_clientes,
            'proveedores', v_cant_proveedores
        )
    );
END;
$function$;
