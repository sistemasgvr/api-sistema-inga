-- Permisos del módulo de caja y turnos (M11).
--
-- Un archivo por módulo, igual que personas.sql. Ejecutar después de
-- auth_permisos.sql. Es idempotente: se puede correr las veces que haga falta.
--
-- Nota sobre cómo separé los permisos de turno: no uso el clásico
-- crear/editar/eliminar porque acá las acciones no son esas. Abrir y cerrar un
-- turno son operaciones distintas y con distinto peso, y "ver el histórico" es
-- algo que el administrador necesita aunque nunca vaya a tocar una caja.

INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
-- MÓDULO: Cajas físicas
('cajas.listar',   'Listar cajas',          'Permite consultar las cajas y ver si tienen turno abierto', 'Caja', 1),
('cajas.ver',      'Ver detalle de caja',   'Permite consultar una caja por ID', 'Caja', 1),
('cajas.crear',    'Crear caja',            'Permite registrar nuevas cajas físicas', 'Caja', 1),
('cajas.editar',   'Editar caja',           'Permite modificar el código y nombre de una caja', 'Caja', 1),
('cajas.eliminar', 'Desactivar caja',       'Permite dar de baja una caja sin turno abierto', 'Caja', 1),
('cajas.activar',  'Activar caja',          'Permite reactivar una caja dada de baja', 'Caja', 1),

-- MÓDULO: Turnos de caja
('turnos.listar',      'Listar turnos',              'Permite consultar el historial de turnos y sus diferencias', 'Turnos', 1),
('turnos.ver',         'Ver detalle de turno',       'Permite consultar un turno, su resumen y sus movimientos', 'Turnos', 1),
('turnos.abrir',       'Abrir turno',                'Permite abrir un turno de caja con monto inicial', 'Turnos', 1),
('turnos.cerrar',      'Cerrar turno',               'Permite cerrar el turno declarando el efectivo contado', 'Turnos', 1),
('turnos.movimientos', 'Registrar movimientos',      'Permite registrar y anular ingresos y egresos de caja', 'Turnos', 1),
('turnos.arqueo',      'Registrar arqueo',           'Permite guardar el conteo de billetes y monedas', 'Turnos', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
