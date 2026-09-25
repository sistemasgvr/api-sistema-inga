CREATE OR REPLACE FUNCTION gen_obtener_opciones_lista(
    p_codigo_lista VARCHAR(50)
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_registro JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', o.id,
            'codigo', o.codigo,
            'nombre', o.nombre,
            'valor_entero', o.valor_entero,
            'orden', o.orden
        ) ORDER BY o.orden ASC, o.nombre ASC
    )
    INTO v_registro
    FROM gen_lista_opcion o
    JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.codigo = UPPER(p_codigo_lista)
      AND l.estado = 1
      AND o.estado = 1;

    RETURN jsonb_build_object(
        'registro', COALESCE(v_registro, '[]'::jsonb),
        'error', NULL
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'registro', NULL,
        'error', SQLERRM
    );
END;
$$;