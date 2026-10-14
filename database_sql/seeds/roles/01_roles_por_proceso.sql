-- Permisos de los roles operativos, según los procesos del restaurante.
--
-- Ejecutar después de todos los seeds de permisos. Es idempotente:
--   - crea el rol si no existe; si existe, respeta su nombre y descripción;
--   - asigna (o reactiva) los permisos de su proceso;
--   - da de baja (estado = 0) los permisos que no corresponden a su proceso,
--     para que la matriz quede igual a esta definición. ADMIN no pierde nada.
-- Los roles que no están aquí (p. ej. PRUEBA, DEMOSTRACION) no se tocan.
--
-- Dependencias que no se ven a simple vista:
--   - Mesas carga la carta con productos.listar/ver y busca o crea clientes con
--     personas.*; el cierre del pedido lista estaciones y convenios.
--   - La cola de impresión exige estaciones.listar y pedidos.comandar.
--   - Anular exige que el propio usuario tenga pedidos.anular
--     (ven_autorizar_anulacion), por eso el mozo no anula: lo hace OPERARIO.
--   - pedidos.estado solo pide la precuenta; cobrar, cobrar a crédito y cerrar
--     el pedido exigen pedidos.cobrar.

BEGIN;

INSERT INTO auth_rol (codigo, nombre, descripcion, estado) VALUES
('ADMIN',    'Administración',     'Acceso a todos los módulos del sistema', 1),
('CAJERO',   'Caja',               'Abre y cierra turno, cobra pedidos y registra compras del día', 1),
('MOZO',     'Mozo',               'Abre pedidos, comanda, pide precuenta y entrega', 1),
('CHEF',     'Cocina',             'Prepara y despacha los productos comandados', 1),
('BARMAN',   'Barra',              'Prepara y despacha las bebidas comandadas', 1),
('OPERARIO', 'Operario Principal', 'Supervisa el salón, autoriza anulaciones y consulta caja', 1)
ON CONFLICT (codigo) DO NOTHING;

CREATE TEMP TABLE tmp_rol_proceso (rol VARCHAR(50), permiso VARCHAR(80)) ON COMMIT DROP;

INSERT INTO tmp_rol_proceso (rol, permiso) VALUES
-- CAJERO
('CAJERO','turnos.ver'),('CAJERO','turnos.abrir'),('CAJERO','turnos.cerrar'),
('CAJERO','turnos.movimientos'),('CAJERO','turnos.arqueo'),
('CAJERO','ambientes.listar'),('CAJERO','pedidos.ver'),('CAJERO','pedidos.abrir'),
('CAJERO','pedidos.editar'),('CAJERO','pedidos.comandar'),('CAJERO','pedidos.estado'),
('CAJERO','pedidos.entregar'),('CAJERO','pedidos.cobrar'),
('CAJERO','productos.listar'),('CAJERO','productos.ver'),
('CAJERO','personas.listar'),('CAJERO','personas.ver'),('CAJERO','personas.crear'),
('CAJERO','convenios.listar'),('CAJERO','cxc.consumo'),
('CAJERO','estaciones.listar'),
('CAJERO','gdo.listar'),('CAJERO','gdo.registrar'),
-- El menú "Gastos" pide gastos.listar en el grupo; sin él, el cajero no ve
-- "Compras del día". Quitarlo cuando cada opción del menú tenga su permiso.
('CAJERO','gastos.listar'),

-- MOZO
('MOZO','ambientes.listar'),('MOZO','pedidos.ver'),('MOZO','pedidos.abrir'),
('MOZO','pedidos.editar'),('MOZO','pedidos.comandar'),('MOZO','pedidos.estado'),
('MOZO','pedidos.entregar'),
('MOZO','productos.listar'),('MOZO','productos.ver'),
('MOZO','personas.listar'),('MOZO','personas.crear'),

-- CHEF (cocina) y BARMAN (barra): mismo proceso de preparación y despacho
('CHEF','produccion.preparar'),('CHEF','pedidos.entregar'),('CHEF','inventario.ver'),
('BARMAN','produccion.preparar'),('BARMAN','pedidos.entregar'),('BARMAN','inventario.ver'),

-- OPERARIO (supervisor de salón)
('OPERARIO','ambientes.listar'),('OPERARIO','ambientes.gestionar'),
('OPERARIO','pedidos.ver'),('OPERARIO','pedidos.abrir'),('OPERARIO','pedidos.editar'),
('OPERARIO','pedidos.comandar'),('OPERARIO','pedidos.estado'),('OPERARIO','pedidos.entregar'),
('OPERARIO','pedidos.anular'),
('OPERARIO','productos.listar'),('OPERARIO','productos.ver'),('OPERARIO','productos.editar'),
('OPERARIO','personas.listar'),('OPERARIO','personas.ver'),('OPERARIO','personas.crear'),
('OPERARIO','convenios.listar'),('OPERARIO','estaciones.listar'),
('OPERARIO','turnos.listar'),('OPERARIO','turnos.ver'),('OPERARIO','cajas.listar'),
('OPERARIO','inventario.ver');

-- ADMIN: todos los permisos activos.
INSERT INTO tmp_rol_proceso (rol, permiso)
SELECT 'ADMIN', codigo FROM auth_permiso WHERE estado = 1;

INSERT INTO auth_rol_permiso (id_rol, id_permiso, estado)
SELECT r.id, p.id, 1
FROM tmp_rol_proceso t
JOIN auth_rol r     ON r.codigo = t.rol
JOIN auth_permiso p ON p.codigo = t.permiso AND p.estado = 1
ON CONFLICT (id_rol, id_permiso) DO UPDATE
SET estado = 1, fecha_modificacion = CURRENT_TIMESTAMP;

UPDATE auth_rol_permiso rp
SET estado = 0, fecha_modificacion = CURRENT_TIMESTAMP
FROM auth_rol r, auth_permiso p
WHERE rp.id_rol = r.id
  AND rp.id_permiso = p.id
  AND rp.estado = 1
  AND r.codigo IN ('CAJERO','MOZO','CHEF','BARMAN','OPERARIO')
  AND NOT EXISTS (
    SELECT 1 FROM tmp_rol_proceso t WHERE t.rol = r.codigo AND t.permiso = p.codigo
  );

COMMIT;
