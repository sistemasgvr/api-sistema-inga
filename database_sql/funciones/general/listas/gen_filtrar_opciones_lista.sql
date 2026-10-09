CREATE OR REPLACE FUNCTION public.gen_filtrar_opciones_lista(p_id BIGINT,p_tipo INTEGER)
RETURNS JSON LANGUAGE sql AS $$
 SELECT json_build_object('registro',(SELECT json_build_object('id',l.id,'codigo',l.codigo,'nombre',l.nombre,'descripcion',l.descripcion,
  'opciones',COALESCE((SELECT json_agg(o ORDER BY o.orden,o.id) FROM gen_lista_opcion o
   WHERE o.id_lista=l.id AND o.estado=1 AND (p_tipo IS NULL OR o.valor_entero=p_tipo)),'[]'::JSON))
 FROM gen_lista l WHERE l.id=p_id AND l.estado=1));
$$;
