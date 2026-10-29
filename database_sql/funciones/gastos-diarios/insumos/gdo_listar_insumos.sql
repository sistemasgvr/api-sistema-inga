DROP FUNCTION IF EXISTS gdo_listar_insumos(
    p_busqueda VARCHAR,
    p_id_categoria BIGINT,
    p_estado INT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION gdo_listar_insumos(
    p_busqueda VARCHAR DEFAULT '',
    p_id_categoria BIGINT DEFAULT NULL,
    p_estado INT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_cant_total BIGINT;
    v_cant_activos BIGINT;
    v_cant_inactivos BIGINT;
    v_cant_categorias BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE i.estado = 1),
        COUNT(*) FILTER (WHERE i.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM gdo_insumo i
    WHERE (p_id_empresa IS NULL OR i.id_empresa = p_id_empresa);

    SELECT COUNT(*) INTO v_cant_categorias
    FROM gdo_categoria WHERE estado = 1
      AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa);

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.orden, x.nombre), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            c.id,
            c.codigo,
            c.nombre,
            c.orden,
            c.estado,
            COALESCE((
                SELECT json_agg(row_to_json(y) ORDER BY y.nombre)
                FROM (
                    SELECT
                        i.id,
                        i.id_categoria,
                        i.nombre,
                        i.precio_referencial,
                        i.id_proveedor_habitual,
                        COALESCE(
                            NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                            p.razon_social
                        ) AS nombre_proveedor_habitual,
                        i.estado
                    FROM gdo_insumo i
                    LEFT JOIN cli_persona p ON i.id_proveedor_habitual = p.id AND (p_id_empresa IS NULL OR p.id_empresa = p_id_empresa)
                    WHERE i.id_categoria = c.id
                      AND (p_id_empresa IS NULL OR i.id_empresa = p_id_empresa)
                      AND (p_estado IS NULL OR i.estado = p_estado)
                      AND (
                          p_busqueda = ''
                          OR LOWER(i.nombre) LIKE LOWER('%' || p_busqueda || '%')
                      )
                ) y
            ), '[]'::JSON) AS insumos
        FROM gdo_categoria c
        WHERE c.estado = 1
          AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
          AND (p_id_categoria IS NULL OR c.id = p_id_categoria)
          AND (
              p_busqueda = ''
              OR EXISTS (
                  SELECT 1 FROM gdo_insumo i2
                  WHERE i2.id_categoria = c.id
                    AND (p_id_empresa IS NULL OR i2.id_empresa = p_id_empresa)
                    AND (p_estado IS NULL OR i2.estado = p_estado)
                    AND LOWER(i2.nombre) LIKE LOWER('%' || p_busqueda || '%')
              )
          )
    ) x;

    RETURN json_build_object(
        'registros', v_registros,
        'resumen', json_build_object(
            'total', v_cant_total,
            'activos', v_cant_activos,
            'inactivos', v_cant_inactivos,
            'categorias', v_cant_categorias
        )
    );
END;
$function$;