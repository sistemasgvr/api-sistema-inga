-- Permisos del módulo de Cuentas por Cobrar al consorcio (M13).
--
-- Un archivo por módulo. Ejecutar después de 01_auth.sql.
-- Es idempotente: se puede correr las veces que haga falta.
--
-- Nota sobre `cxc.consumo`: lo va a usar M12 automáticamente al cobrar un
-- pedido con medio de pago "crédito", así que el cajero lo necesita. El abono
-- lo registra el administrador cuando la empresa paga, y por eso va aparte.
--
-- Nota sobre `cxc.ajustar`: cubre también anular un movimiento. Anular y
-- ajustar son la misma decisión vista de dos formas — corregir un saldo ya
-- escrito — y deberían estar en las mismas manos.

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
