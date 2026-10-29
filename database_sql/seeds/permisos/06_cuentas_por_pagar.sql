INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
('cxp.listar',  'Consultar cuentas por pagar', 'Permite ver saldos por proveedor, movimientos y el reporte del período', 'Cuentas por Pagar', 1),
('cxp.cargo',   'Registrar cargo',             'Permite registrar una compra a crédito que aumenta la deuda', 'Cuentas por Pagar', 1),
('cxp.abono',   'Registrar abono',             'Permite registrar el pago semanal al proveedor', 'Cuentas por Pagar', 1),
('cxp.ajustar', 'Ajustar y anular',            'Permite corregir el saldo a mano y anular el último movimiento', 'Cuentas por Pagar', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
