-- Listo el saldo deudor de cada cliente del consorcio, usando
-- vw_cxc_saldo_persona.
--
-- Es la pantalla principal del módulo: "quién nos debe y cuánto".
--
-- Ordeno por saldo descendente porque al administrador le importa primero quién
-- le debe más, no el orden alfabético.
--
-- Dos filtros que vienen de dos usos distintos:
--   p_solo_con_deuda → el dashboard quiere solo a quienes deben.
--   p_id_convenio    → la pantalla de una empresa quiere solo a su gente,
--                      porque el corte quincenal se envía por empresa.
--
-- El resumen incluye `clientes_sobre_limite`: cuántos pasaron el tope de crédito
-- de su convenio. Como decidí advertir en vez de bloquear (ver
-- cxc_registrar_consumo), este contador es el que hace que la advertencia no se
-- pierda.
CREATE OR REPLACE FUNCTION cxc_listar_saldos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_solo_con_deuda BOOLEAN DEFAULT FALSE,
    p_id_convenio BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_deuda_total NUMERIC(12,2);
    v_clientes_con_deuda BIGINT;
    v_clientes_total BIGINT;
    v_sobre_limite BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- El resumen mira SIEMPRE el universo completo, sin el filtro de búsqueda:
    -- lo que nos deben en total no debe cambiar porque alguien esté buscando.
    -- El filtro de convenio sí lo respeto, porque ahí el "total" que se espera
    -- es el de esa empresa.
    SELECT
        COALESCE(SUM(v.saldo) FILTER (WHERE v.saldo > 0), 0),
        COUNT(*) FILTER (WHERE v.saldo > 0),
        COUNT(*),
        COUNT(*) FILTER (WHERE COALESCE(v.limite_credito, 0) > 0 AND v.saldo > v.limite_credito)
    INTO v_deuda_total, v_clientes_con_deuda, v_clientes_total, v_sobre_limite
    FROM vw_cxc_saldo_persona v
    WHERE (p_id_convenio IS NULL OR v.id_convenio = p_id_convenio);

    SELECT COUNT(*) INTO v_total
    FROM vw_cxc_saldo_persona v
    WHERE (p_solo_con_deuda = FALSE OR v.saldo > 0)
      AND (p_id_convenio IS NULL OR v.id_convenio = p_id_convenio)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(v.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR COALESCE(v.num_documento, '') LIKE '%' || p_busqueda || '%'
          OR LOWER(COALESCE(v.convenio, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            v.id_persona,
            v.nombre,
            v.num_documento,
            v.id_convenio,
            v.convenio,
            v.limite_credito,
            v.saldo,
            v.total_cargos,
            v.total_abonos,
            v.ultimo_abono,
            -- Bandera para pintar la fila en rojo en el front sin que tenga que
            -- recalcular el tope.
            (COALESCE(v.limite_credito, 0) > 0 AND v.saldo > v.limite_credito) AS supera_limite,
            -- Cuánto le queda de crédito. NULL = sin tope definido.
            CASE
                WHEN COALESCE(v.limite_credito, 0) > 0 THEN v.limite_credito - v.saldo
                ELSE NULL
            END AS credito_disponible,
            CASE
                WHEN v.ultimo_abono IS NULL THEN NULL
                ELSE (CURRENT_DATE - v.ultimo_abono::DATE)
            END AS dias_sin_abonar
        FROM vw_cxc_saldo_persona v
        WHERE (p_solo_con_deuda = FALSE OR v.saldo > 0)
          AND (p_id_convenio IS NULL OR v.id_convenio = p_id_convenio)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(v.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR COALESCE(v.num_documento, '') LIKE '%' || p_busqueda || '%'
              OR LOWER(COALESCE(v.convenio, '')) LIKE LOWER('%' || p_busqueda || '%')
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
            'clientes_con_deuda', v_clientes_con_deuda,
            'clientes_total', v_clientes_total,
            'clientes_sobre_limite', v_sobre_limite
        )
    );
END;
$function$;
