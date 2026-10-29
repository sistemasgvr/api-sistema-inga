-- Listo las categorías de gasto en árbol: raíces con sus subcategorías anidadas (un solo nivel).
DROP FUNCTION IF EXISTS gad_listar_categorias(
    p_tipo_gasto INT,
    p_estado INT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION gad_listar_categorias(
    p_tipo_gasto INT DEFAULT NULL,
    p_estado INT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
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
    FROM gad_categoria c
    WHERE (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa);

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.orden, x.nombre), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            c.id,
            c.nombre,
            c.tipo_gasto,
            CASE c.tipo_gasto WHEN 1 THEN 'Fijo' ELSE 'Variable' END AS tipo_gasto_nombre,
            c.orden,
            c.estado,
            (
                SELECT COUNT(*)
                FROM gad_gasto g
                WHERE g.id_categoria = c.id AND g.estado = 1
                  AND (p_id_empresa IS NULL OR g.id_empresa = p_id_empresa)
            ) AS gastos_registrados,
            -- Las hijas usan el mismo filtro de estado que la raíz.
            COALESCE((
                SELECT json_agg(row_to_json(s) ORDER BY s.orden, s.nombre)
                FROM (
                    SELECT
                        h.id,
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
                              AND (p_id_empresa IS NULL OR g2.id_empresa = p_id_empresa)
                        ) AS gastos_registrados
                    FROM gad_categoria h
                    WHERE h.id_categoria_padre = c.id
                      AND (p_estado IS NULL OR h.estado = p_estado)
                      AND (p_id_empresa IS NULL OR h.id_empresa = p_id_empresa)
                ) s
            ), '[]'::JSON) AS subcategorias
        FROM gad_categoria c
        WHERE c.id_categoria_padre IS NULL
          AND (p_estado IS NULL OR c.estado = p_estado)
          AND (p_tipo_gasto IS NULL OR c.tipo_gasto = p_tipo_gasto)
          AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
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
