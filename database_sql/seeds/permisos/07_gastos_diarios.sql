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
