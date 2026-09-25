CREATE OR REPLACE FUNCTION gen_listar_listas()
RETURNS JSON
LANGUAGE sql
AS $function$
  SELECT COALESCE(json_agg(l ORDER BY l.nombre, l.id), '[]'::JSON)
  FROM (
    SELECT id, codigo, nombre, descripcion
    FROM gen_lista
    WHERE estado = 1
  ) l;
$function$;
