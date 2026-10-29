INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
-- MÓDULO: Categorías de gasto
('gastos.categorias.listar',    'Listar categorías de gasto',   'Permite consultar el árbol de categorías fijas y variables', 'Gastos administrativos', 1),
('gastos.categorias.gestionar', 'Gestionar categorías de gasto', 'Permite crear, editar, dar de baja y reactivar categorías', 'Gastos administrativos', 1),

-- MÓDULO: Gastos
('gastos.listar',    'Listar gastos administrativos', 'Permite consultar los gastos y el reporte mensual', 'Gastos administrativos', 1),
('gastos.registrar', 'Registrar gasto',               'Permite registrar y editar gastos administrativos', 'Gastos administrativos', 1),
('gastos.anular',    'Anular gasto',                  'Permite anular un gasto mal registrado', 'Gastos administrativos', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
