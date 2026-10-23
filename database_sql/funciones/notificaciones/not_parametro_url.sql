-- Codifica un texto para usarlo como valor de un parámetro de la ruta del front.
DROP FUNCTION IF EXISTS public.not_parametro_url(p_texto TEXT);
CREATE OR REPLACE FUNCTION public.not_parametro_url(p_texto TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT replace(replace(replace(replace(replace(replace(replace(
    COALESCE(p_texto, ''), '%', '%25'), '&', '%26'), '#', '%23'), '+', '%2B'),
    ' ', '%20'), '?', '%3F'), '=', '%3D');
$$;
