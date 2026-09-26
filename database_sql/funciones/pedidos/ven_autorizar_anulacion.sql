CREATE OR REPLACE FUNCTION public.ven_autorizar_anulacion(p_usuario BIGINT, p_autoriza BIGINT, p_motivo TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  IF p_autoriza IS DISTINCT FROM p_usuario OR p_usuario IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth_usuario u JOIN auth_usuario_rol ur ON ur.id_usuario = u.id AND ur.estado = 1
    JOIN auth_rol r ON r.id = ur.id_rol AND r.estado = 1
    WHERE u.id = p_usuario AND u.estado = 1 AND r.codigo IN ('ADMIN', 'CAJERO')
  ) THEN RAISE EXCEPTION 'La anulación debe ser autorizada por el usuario autenticado con rol ADMIN o CAJERO' USING ERRCODE = '42501'; END IF;
  IF NULLIF(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo de anulación'; END IF;
END;
$$;
