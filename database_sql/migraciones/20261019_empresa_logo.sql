-- Datos de la empresa para tickets (Configuración → Empresa). Reejecutable.
--   logo_url:    logo original (Supabase Storage), para PDFs o la futura facturación.
--   logo_ticket: PNG en blanco y negro listo para la impresora térmica (base64),
--                así la PC que imprime no descarga ni procesa la imagen.
ALTER TABLE gen_empresa ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE gen_empresa ADD COLUMN IF NOT EXISTS logo_ticket TEXT;

INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
('empresa.ver',    'Ver datos de la empresa',    'Permite consultar RUC, razón social, dirección y logo', 'Empresa', 1),
('empresa.editar', 'Editar datos de la empresa', 'Permite modificar RUC, razón social, dirección y logo', 'Empresa', 1)
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre, descripcion = EXCLUDED.descripcion,
    modulo = EXCLUDED.modulo, estado = EXCLUDED.estado;

-- ADMIN tiene todos los permisos activos (ver seeds/roles/01_roles_por_proceso.sql).
INSERT INTO auth_rol_permiso (id_rol, id_permiso, estado)
SELECT r.id, p.id, 1 FROM auth_rol r JOIN auth_permiso p ON p.codigo IN ('empresa.ver', 'empresa.editar')
WHERE r.codigo = 'ADMIN'
ON CONFLICT (id_rol, id_permiso) DO UPDATE SET estado = 1, fecha_modificacion = CURRENT_TIMESTAMP;
