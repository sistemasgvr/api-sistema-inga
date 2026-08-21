INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
-- MÓDULO: Usuarios
('usuarios.listar', 'Listar usuarios', 'Permite consultar el listado general de usuarios', 'Usuarios', 1),
('usuarios.ver', 'Ver detalle de usuario', 'Permite consultar la información detallada de un usuario por ID', 'Usuarios', 1),
('usuarios.crear', 'Crear usuario', 'Permite registrar nuevos usuarios en el sistema', 'Usuarios', 1),
('usuarios.editar', 'Editar usuario', 'Permite modificar los datos de un usuario existente', 'Usuarios', 1),
('usuarios.eliminar', 'Desactivar usuario', 'Permite dar de baja lógica a un usuario', 'Usuarios', 1),
('usuarios.activar', 'Activar usuario', 'Permite reactivar un usuario inactivo', 'Usuarios', 1),

-- MÓDULO: Roles
('roles.listar', 'Listar roles', 'Permite consultar el listado general de roles', 'Roles', 1),
('roles.ver', 'Ver detalle de rol', 'Permite consultar un rol por ID y sus permisos asignados', 'Roles', 1),
('roles.crear', 'Crear rol', 'Permite registrar nuevos roles en el sistema', 'Roles', 1),
('roles.editar', 'Editar rol y asignar permisos', 'Permite modificar roles y gestionar su matriz de permisos', 'Roles', 1),
('roles.eliminar', 'Desactivar rol', 'Permite dar de baja lógica a un rol', 'Roles', 1),
('roles.activar', 'Activar rol', 'Permite reactivar un rol inactivo', 'Roles', 1)

ON CONFLICT (codigo) DO UPDATE 
SET 
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;