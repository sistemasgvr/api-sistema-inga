-- Permisos del dashboard gerencial y de la reportería.
--
-- Un permiso por reporte porque cada uno expone datos sensibles distintos:
-- quien revisa la caja no tiene por qué ver la planilla. `dashboard.ver` y
-- `reportes.general` muestran la rentabilidad completa (ventas, costos,
-- gastos y planilla), así que conviene dejarlos en pocas manos.
--
-- Sin `dashboard.ver` la página /dashboard sigue abriendo, pero solo con el
-- saludo: no pide ni muestra indicadores.
--
-- Ejecutar después de 01_auth.sql. Es idempotente. Asigna todo a ADMIN; el
-- resto de roles se ajusta desde la pantalla de Roles.

INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
('dashboard.ver',       'Ver dashboard gerencial',  'Ver ventas, platos más vendidos, gastos, planilla y rentabilidad en el dashboard', 'Reportes', 1),
('reportes.ventas',     'Reporte de ventas',        'Platos vendidos, ventas por medio de pago, canal y mozo, y listado de ventas', 'Reportes', 1),
('reportes.gastos',     'Reporte de gastos',        'Compras del día por fecha e ítem y gastos administrativos', 'Reportes', 1),
('reportes.caja',       'Reporte de caja',          'Turnos, cierres, diferencias y movimientos de caja', 'Reportes', 1),
('reportes.cuentas',    'Reporte de cuentas',       'Saldos y movimientos de cuentas por cobrar y por pagar', 'Reportes', 1),
('reportes.planilla',   'Reporte de planilla',      'Pagos de planilla por trabajador', 'Reportes', 1),
('reportes.inventario', 'Reporte de inventario',    'Stock valorizado, productos bajo mínimo y movimientos de almacén', 'Reportes', 1),
('reportes.general',    'Reporte general',          'Estado de resultados consolidado: ventas, costo, gastos, planilla, caja, cuentas e inventario', 'Reportes', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;

INSERT INTO public.auth_rol_permiso (id_rol, id_permiso, estado)
SELECT r.id, p.id, 1
FROM public.auth_rol r
JOIN public.auth_permiso p ON p.codigo IN (
  'dashboard.ver', 'reportes.ventas', 'reportes.gastos', 'reportes.caja',
  'reportes.cuentas', 'reportes.planilla', 'reportes.inventario', 'reportes.general'
)
WHERE r.codigo = 'ADMIN'
ON CONFLICT (id_rol, id_permiso) DO UPDATE
SET estado = 1, fecha_modificacion = CURRENT_TIMESTAMP;
