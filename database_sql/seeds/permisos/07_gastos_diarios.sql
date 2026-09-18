-- Permisos del módulo de Gastos Diarios Operativos (M14).
--
-- Un archivo por módulo. Ejecutar después de 01_auth.sql.
-- Es idempotente: se puede correr las veces que haga falta.
--
-- Nota sobre `gdo.registrar`: cubre tanto agregar una compra como crear un
-- insumo nuevo. Es deliberado — el alcance pide que el cajero pueda crear el
-- producto "al vuelo" desde el mismo formulario cuando no está en la lista.
-- Separarlo haría que quien registra compras no pueda agregar lo que falta,
-- que es justo el caso que el cliente quería evitar.

INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
('gdo.listar',             'Consultar gastos diarios',  'Permite ver la lista de insumos, el historial de días y el cuadre diario', 'Gastos Diarios', 1),
('gdo.registrar',          'Registrar compra del día',  'Permite abrir el día, agregar compras y crear insumos al vuelo', 'Gastos Diarios', 1),
('gdo.anular',             'Anular compra',             'Permite anular una compra mal registrada y revertir su deuda', 'Gastos Diarios', 1),
('gdo.insumos.gestionar',  'Gestionar lista de insumos', 'Permite editar y dar de baja insumos de la lista maestra', 'Gastos Diarios', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
