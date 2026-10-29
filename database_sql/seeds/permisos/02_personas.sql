INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
-- MÓDULO: Personas (clientes y proveedores)
('personas.listar',   'Listar personas',           'Permite consultar el listado de clientes y proveedores', 'Personas', 1),
('personas.ver',      'Ver detalle de persona',    'Permite consultar una persona por ID, incluido su saldo de crédito', 'Personas', 1),
('personas.crear',    'Crear persona',             'Permite registrar nuevos clientes o proveedores', 'Personas', 1),
('personas.editar',   'Editar persona',            'Permite modificar los datos de una persona existente', 'Personas', 1),
('personas.eliminar', 'Desactivar persona',        'Permite dar de baja lógica a una persona', 'Personas', 1),
('personas.activar',  'Activar persona',           'Permite reactivar una persona dada de baja', 'Personas', 1),

-- MÓDULO: Convenios de crédito
('convenios.listar',   'Listar convenios',         'Permite consultar los convenios de crédito del consorcio', 'Convenios', 1),
('convenios.ver',      'Ver detalle de convenio',  'Permite consultar un convenio por ID', 'Convenios', 1),
('convenios.crear',    'Crear convenio',           'Permite registrar nuevos convenios de crédito', 'Convenios', 1),
('convenios.editar',   'Editar convenio',          'Permite modificar el límite de crédito y la condición de pago', 'Convenios', 1),
('convenios.eliminar', 'Desactivar convenio',      'Permite dar de baja lógica a un convenio sin clientes asignados', 'Convenios', 1),
('convenios.activar',  'Activar convenio',         'Permite reactivar un convenio dado de baja', 'Convenios', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
