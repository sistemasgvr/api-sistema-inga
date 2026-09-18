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



INSERT INTO pro_unidad_medida (codigo, codigo_sunat, nombre, simbolo, es_fraccionable) VALUES
    ('NIU', 'NIU', 'Unidad', 'und', FALSE),
    ('KG',  'KGM', 'Kilogramo', 'kg', TRUE),
    ('G',   'GRM', 'Gramo', 'g', TRUE),
    ('L',   'LTR', 'Litro', 'L', TRUE),
    ('ML',  'MLT', 'Mililitro', 'ml', TRUE),
    ('OZ',  NULL,  'Onza', 'oz', TRUE),
    ('DASH', NULL, 'Dash (~0.5 oz)', 'dash', TRUE),
    ('PORC', NULL, 'Porción', 'pzc', FALSE),
    ('PRESA', NULL, 'Presa', 'presa', FALSE),
    ('POTE', NULL, 'Pote / porción salsa', 'pote', FALSE),
    ('BOT', NULL,  'Botella', 'bot', FALSE),
    ('CAJA', NULL, 'Caja', 'caja', FALSE),
    ('SACO', NULL, 'Saco', 'saco', FALSE),
    ('PLANCHA', NULL, 'Plancha', 'plancha', FALSE),
    ('DAMA', NULL, 'Damajuana 3.8 L', 'dama', FALSE)
ON CONFLICT (codigo) DO NOTHING;



INSERT INTO pro_unidad_conversion (id_unidad_origen, id_unidad_destino, factor)
SELECT o.id, d.id, v.factor
FROM (VALUES
    ('KG', 'G', 1000),
    ('L', 'ML', 1000),
    ('BOT', 'ML', 750),
    ('BOT', 'OZ', 25.3605),
    ('OZ', 'ML', 29.5735),
    ('DASH', 'OZ', 0.5),
    ('CAJA', 'BOT', 12),
    ('DAMA', 'ML', 3800),
    ('DAMA', 'OZ', 128.494)
) AS v(origen, destino, factor)
JOIN pro_unidad_medida o ON o.codigo = v.origen
JOIN pro_unidad_medida d ON d.codigo = v.destino
ON CONFLICT (id_unidad_origen, id_unidad_destino) DO NOTHING;