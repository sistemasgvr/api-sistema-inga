INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
('ambientes.listar', 'Consultar ambientes', 'Ver salones, plano y estados de las mesas', 'Ambientes', 1),
('ambientes.gestionar', 'Gestionar ambientes', 'Crear, editar, desactivar y reactivar salones y mesas', 'Ambientes', 1)
ON CONFLICT (codigo) DO UPDATE SET nombre = EXCLUDED.nombre, descripcion = EXCLUDED.descripcion,
modulo = EXCLUDED.modulo, estado = EXCLUDED.estado;
