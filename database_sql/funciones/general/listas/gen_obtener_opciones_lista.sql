CREATE OR REPLACE FUNCTION gen_obtener_opciones_lista(p_id BIGINT)
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
    WHERE l.id = p_id AND l.estado = 1
    LIMIT 1
  ));
$function$;
