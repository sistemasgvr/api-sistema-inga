CREATE OR REPLACE FUNCTION public.ven_autorizar_anulacion(p_usuario BIGINT, p_autoriza BIGINT, p_motivo TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  IF p_autoriza IS DISTINCT FROM p_usuario OR p_usuario IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth_usuario_datos u
    WHERE u.id = p_usuario AND u.estado = 1
      AND (u.es_super_admin OR EXISTS (
        SELECT 1 FROM auth_usuario_rol ur
        JOIN auth_rol r ON r.id = ur.id_rol AND r.estado = 1
        JOIN auth_rol_permiso rp ON rp.id_rol = r.id AND rp.estado = 1
        JOIN auth_permiso p ON p.id = rp.id_permiso AND p.estado = 1
        WHERE ur.id_usuario = u.id AND ur.estado = 1 AND p.codigo = 'pedidos.anular'
      ))
  ) THEN RAISE EXCEPTION 'La anulación requiere el usuario autenticado con permiso pedidos.anular o superadministrador' USING ERRCODE = '42501'; END IF;
  IF NULLIF(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo de anulación'; END IF;
END;
$$;
