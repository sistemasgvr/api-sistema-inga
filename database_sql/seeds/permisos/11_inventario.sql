INSERT INTO auth_permiso(codigo,nombre,descripcion,modulo,estado) VALUES
('inventario.ver','Consultar inventario','Stock, movimientos y kardex','Inventario',1),
('inventario.gestionar','Gestionar inventario','Registrar y confirmar movimientos','Inventario',1),
('produccion.preparar','Registrar preparación','Consumir ingredientes y producir platos','Producción',1),
('pedidos.entregar','Entregar productos','Descontar productos terminados reservados','Pedidos',1)
ON CONFLICT(codigo) DO UPDATE SET nombre=EXCLUDED.nombre,descripcion=EXCLUDED.descripcion;
UPDATE auth_permiso SET descripcion='Enviar comanda y reservar productos terminados' WHERE codigo='pedidos.comandar';
