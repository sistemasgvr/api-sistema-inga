-- Lista por su código (PEDIDO_TIPO, MEDIO_PAGO, SUNAT_AMBIENTE...) con sus opciones
-- activas ordenadas. El código es la referencia estable entre bases de datos; el id
-- cambia de una instalación a otra. p_tipo filtra por valor_entero (motivos de
-- movimiento de almacén según su tipo).
DROP FUNCTION IF EXISTS gen_obtener_opciones_lista_por_codigo(p_codigo VARCHAR, p_tipo INTEGER);
CREATE OR REPLACE FUNCTION gen_obtener_opciones_lista_por_codigo(
    p_codigo VARCHAR,
    p_tipo INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    SELECT json_build_object('registro', (
        SELECT json_build_object(
            'id', l.id,
            'codigo', l.codigo,
            'nombre', l.nombre,
            'descripcion', l.descripcion,
            'opciones', COALESCE((
                SELECT json_agg(o ORDER BY o.orden, o.id)
                FROM (
                    SELECT id, id_lista, codigo, nombre, descripcion, valor_entero, orden
                    FROM gen_lista_opcion
                    WHERE id_lista = l.id
                      AND estado = 1
                      AND (p_tipo IS NULL OR valor_entero = p_tipo)
                ) o
            ), '[]'::JSON)
        )
        FROM gen_lista l
        WHERE l.codigo = UPPER(TRIM(p_codigo))
          AND l.estado = 1
        LIMIT 1
    ));
$function$;
