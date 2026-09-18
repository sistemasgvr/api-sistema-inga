-- Listo el saldo deudor de cada proveedor, usando la vista vw_cxp_saldo_proveedor.
--
-- Es la pantalla principal del módulo y la fuente de la alerta "Deudas por
-- pagar" del dashboard.
--
-- Ordeno por saldo descendente a propósito: al administrador le interesa ver
-- primero a quién le debe más, no la lista alfabética.
--
-- El filtro p_solo_con_deuda permite las dos vistas que hacen falta: el
-- dashboard quiere solo a quienes se les debe, y la pantalla de proveedores
-- quiere a todos, incluidos los que están en cero.
CREATE OR REPLACE FUNCTION cxp_listar_saldos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_solo_con_deuda BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_deuda_total NUMERIC(12,2);
    v_proveedores_con_deuda BIGINT;
    v_proveedores_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- El resumen mira SIEMPRE el universo completo, sin el filtro de búsqueda:
    -- la deuda total del negocio no debe cambiar porque alguien esté buscando.
    SELECT
        COALESCE(SUM(v.saldo) FILTER (WHERE v.saldo > 0), 0),
        COUNT(*) FILTER (WHERE v.saldo > 0),
        COUNT(*)
    INTO v_deuda_total, v_proveedores_con_deuda, v_proveedores_total
    FROM vw_cxp_saldo_proveedor v;

    SELECT COUNT(*) INTO v_total
    FROM vw_cxp_saldo_proveedor v
    WHERE (p_solo_con_deuda = FALSE OR v.saldo > 0)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(v.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR COALESCE(v.num_documento, '') LIKE '%' || p_busqueda || '%'
      );

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            v.id_persona,
            v.nombre,
            v.num_documento,
            v.saldo,
            v.total_cargos,
            v.total_abonos,
            v.ultimo_abono,
            -- Días desde el último abono. Sirve para notar que a un proveedor
            -- no se le paga hace tres semanas cuando el corte es semanal.
            CASE
                WHEN v.ultimo_abono IS NULL THEN NULL
                ELSE (CURRENT_DATE - v.ultimo_abono)
            END AS dias_sin_abonar
        FROM vw_cxp_saldo_proveedor v
        WHERE (p_solo_con_deuda = FALSE OR v.saldo > 0)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(v.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR COALESCE(v.num_documento, '') LIKE '%' || p_busqueda || '%'
          )
        ORDER BY v.saldo DESC, v.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'deuda_total', v_deuda_total,
            'proveedores_con_deuda', v_proveedores_con_deuda,
            'proveedores_total', v_proveedores_total
        )
    );
END;
$function$;
