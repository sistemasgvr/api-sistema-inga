INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
('ventas.listar',       'Consultar ventas',        'Ver los pedidos cobrados, sus pagos, comprobantes y comandas', 'Ventas', 1),
('ventas.reimprimir',   'Reimprimir',              'Reimprimir comandas e imprimir el comprobante vigente', 'Ventas', 1),
('ventas.cambiar_pago', 'Cambiar medio de pago',   'Cambiar efectivo, Yape o tarjeta de una venta; recalcula la caja del pago aunque esté cerrada', 'Ventas', 1),
('ventas.reemitir',     'Reemitir comprobante',    'Anular el comprobante vigente y emitir uno nuevo con otro número', 'Ventas', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
