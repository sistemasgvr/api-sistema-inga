CREATE OR REPLACE FUNCTION gen_obtener_lista_opciones(
  p_id BIGINT DEFAULT NULL,
  p_codigo VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
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
          WHERE id_lista = l.id AND estado = 1
        ) o
      ), '[]'::JSON)
    )
    FROM gen_lista l
    WHERE l.estado = 1
      AND ((p_id IS NOT NULL AND p_codigo IS NULL AND l.id = p_id)
        OR (p_id IS NULL AND p_codigo IS NOT NULL AND l.codigo = upper(trim(p_codigo))))
  ));
$function$;
x 