-- Listo las categorías de gasto administrativo en forma de árbol.
--
-- Devuelvo las raíces con sus subcategorías anidadas dentro (`subcategorias`),
-- no una lista plana. El formulario de gasto necesita mostrar "Servicios →
-- Luz / Agua / Internet" agrupado, y armar esa jerarquía en el front a partir
-- de una lista plana obliga a recorrerla dos veces en cada render.
--
-- Solo admito un nivel de anidación: es lo que el alcance pide y evita tener
-- que resolver recursión aquí.
--
-- "gastos_registrados" cuenta cuántos gastos vigentes cuelgan de cada
-- categoría. La pantalla lo usa para avisar antes de dar de baja.
CREATE OR REPLACE FUNCTION gad_listar_categorias(
    p_tipo_gasto INT DEFAULT NULL,
    p_estado INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_cant_total BIGINT;
    v_cant_fijos BIGINT;
    v_cant_variables BIGINT;
    v_cant_inactivos BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE c.tipo_gasto = 1 AND c.estado = 1),
        COUNT(*) FILTER (WHERE c.tipo_gasto = 2 AND c.estado = 1),
        COUNT(*) FILTER (WHERE c.estado = 0)
    INTO v_cant_total, v_cant_fijos, v_cant_variables, v_cant_inactivos
    FROM gad_categoria c;

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.orden, x.nombre), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            c.id,
            c.codigo,
            c.nombre,
            c.tipo_gasto,
            CASE c.tipo_gasto WHEN 1 THEN 'Fijo' ELSE 'Variable' END AS tipo_gasto_nombre,
            c.orden,
            c.estado,
            (
                SELECT COUNT(*)
                FROM gad_gasto g
                WHERE g.id_categoria = c.id AND g.estado = 1
            ) AS gastos_registrados,
            -- Subcategorías anidadas. Uso el mismo filtro de estado que la raíz
            -- para que al ver "solo activas" no aparezcan hijas dadas de baja.
            COALESCE((
                SELECT json_agg(row_to_json(s) ORDER BY s.orden, s.nombre)
                FROM (
                    SELECT
                        h.id,
                        h.codigo,
                        h.nombre,
                        h.tipo_gasto,
                        CASE h.tipo_gasto WHEN 1 THEN 'Fijo' ELSE 'Variable' END AS tipo_gasto_nombre,
                        h.orden,
                        h.estado,
                        h.id_categoria_padre,
                        (
                            SELECT COUNT(*)
                            FROM gad_gasto g2
                            WHERE g2.id_categoria = h.id AND g2.estado = 1
                        ) AS gastos_registrados
                    FROM gad_categoria h
                    WHERE h.id_categoria_padre = c.id
                      AND (p_estado IS NULL OR h.estado = p_estado)
                ) s
            ), '[]'::JSON) AS subcategorias
        FROM gad_categoria c
        WHERE c.id_categoria_padre IS NULL
          AND (p_estado IS NULL OR c.estado = p_estado)
          AND (p_tipo_gasto IS NULL OR c.tipo_gasto = p_tipo_gasto)
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'resumen', json_build_object(
            'total', v_cant_total,
            'fijos', v_cant_fijos,
            'variables', v_cant_variables,
            'inactivos', v_cant_inactivos
        )
    );
END;
$function$;
