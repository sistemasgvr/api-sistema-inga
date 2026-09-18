-- Permisos del módulo de Planilla (M17).
--
-- Un archivo por módulo. Ejecutar después de 01_auth.sql.
-- Es idempotente: se puede correr las veces que haga falta.
--
-- Nota sobre cómo separé los permisos: el mantenimiento de trabajadores va por
-- un lado y los pagos por otro. El sueldo de cada persona es información
-- sensible, así que alguien puede necesitar administrar el personal (dar de
-- alta, corregir un puesto) sin poder ver ni registrar los montos pagados.

INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
-- MÓDULO: Trabajadores
('trabajadores.listar',   'Listar trabajadores',        'Permite consultar el personal que cobra planilla', 'Planilla', 1),
('trabajadores.ver',      'Ver detalle de trabajador',  'Permite consultar un trabajador y su histórico de pagos', 'Planilla', 1),
('trabajadores.crear',    'Crear trabajador',           'Permite registrar nuevo personal en planilla', 'Planilla', 1),
('trabajadores.editar',   'Editar trabajador',          'Permite modificar datos y sueldo referencial', 'Planilla', 1),
('trabajadores.eliminar', 'Desactivar trabajador',      'Permite dar de baja lógica a un trabajador', 'Planilla', 1),
('trabajadores.activar',  'Activar trabajador',         'Permite reactivar un trabajador dado de baja', 'Planilla', 1),

-- MÓDULO: Pagos de planilla
('planilla.pagos.listar',    'Listar pagos de planilla', 'Permite consultar los pagos, montos y el reporte del período', 'Planilla', 1),
('planilla.pagos.registrar', 'Registrar pago',           'Permite registrar el pago de la quincena a un trabajador', 'Planilla', 1),
('planilla.pagos.anular',    'Anular pago',              'Permite anular un pago mal registrado', 'Planilla', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
