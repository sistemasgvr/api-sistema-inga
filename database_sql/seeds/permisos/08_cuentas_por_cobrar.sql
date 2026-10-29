INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
('cxc.listar',   'Consultar cuentas por cobrar', 'Permite ver saldos por cliente, movimientos, estado de cuenta y el reporte de la quincena', 'Cuentas por Cobrar', 1),
('cxc.consumo',  'Registrar consumo a crédito',  'Permite cargar un consumo a la cuenta de un trabajador del consorcio', 'Cuentas por Cobrar', 1),
('cxc.abono',    'Registrar abono del cliente',  'Permite registrar el pago de la empresa o el descuento por planilla', 'Cuentas por Cobrar', 1),
('cxc.ajustar',  'Ajustar y anular movimientos', 'Permite corregir un saldo a mano y anular movimientos mal registrados', 'Cuentas por Cobrar', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
