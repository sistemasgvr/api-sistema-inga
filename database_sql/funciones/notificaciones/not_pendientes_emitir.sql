-- Outbox: toma las notificaciones generadas en SQL que aún no se enviaron por socket
-- y las marca como emitidas. SKIP LOCKED evita que dos instancias envíen la misma.
DROP FUNCTION IF EXISTS public.not_pendientes_emitir(p_limite INTEGER);
CREATE OR REPLACE FUNCTION public.not_pendientes_emitir(
  p_limite INTEGER DEFAULT 100
) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE v_registros JSON;
BEGIN
  WITH sel AS (
    SELECT id FROM notificaciones
    WHERE emitida_en IS NULL
    ORDER BY creada_en
    LIMIT LEAST(GREATEST(COALESCE(p_limite, 100), 1), 500)
    FOR UPDATE SKIP LOCKED
  ), upd AS (
    UPDATE notificaciones n SET emitida_en = now()
    FROM sel WHERE n.id = sel.id
    RETURNING n.id, n.canal, n.titulo, n.mensaje, n.severidad, n.ruta, n.id_referencia,
              n.creada_en, n.ids_usuario_destino
  )
  SELECT COALESCE(json_agg(upd ORDER BY upd.creada_en), '[]'::JSON) INTO v_registros FROM upd;
  RETURN json_build_object('registros', v_registros);
END; $$;
