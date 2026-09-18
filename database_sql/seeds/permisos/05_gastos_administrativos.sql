-- Permisos del módulo de Gastos Administrativos (M16).
--
-- Un archivo por módulo. Ejecutar después de 01_auth.sql.
-- Es idempotente: se puede correr las veces que haga falta.
--
-- Nota sobre cómo los separé: las categorías son configuración (se arman una
-- vez y quedan), así que su mantenimiento va en un solo permiso en vez de uno
-- por acción — abrir seis permisos para algo que se toca una vez al año sería
-- ruido en la matriz de roles. Los gastos sí van separados porque registrar y
-- anular son operaciones de distinto peso.

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
