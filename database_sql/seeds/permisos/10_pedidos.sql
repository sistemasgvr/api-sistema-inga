INSERT INTO public.auth_permiso(codigo,nombre,descripcion,modulo,estado) VALUES
('pedidos.ver','Consultar pedidos','Consultar pedido con ítems y comandas','Pedidos',1),
('pedidos.abrir','Abrir pedidos','Abrir pedido y ocupar mesa','Pedidos',1),
('pedidos.editar','Editar pedidos','Agregar y editar ítems pendientes','Pedidos',1),
('pedidos.comandar','Comandar pedidos','Enviar comanda y descontar stock','Pedidos',1),
('pedidos.estado','Cambiar estado de pedidos','Cambiar estado del pedido','Pedidos',1),
('pedidos.anular','Anular pedidos','Anular ítems y pedidos con autorización','Pedidos',1)
ON CONFLICT(codigo) DO UPDATE SET nombre = EXCLUDED.nombre,descripcion = EXCLUDED.descripcion,modulo = EXCLUDED.modulo,estado = EXCLUDED.estado;
