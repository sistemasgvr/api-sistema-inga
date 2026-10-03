// Sólo PostgreSQL temporal local. No lee .env ni accede a la base del restaurante.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { Client, Pool } = require('pg');
const { ImpresionLogic } = require('../../dist/modules/impresion/logic/impresion.logic');
const { ImpresionModel } = require('../../dist/modules/impresion/models/impresion.model');
const root = path.resolve(__dirname, '../..');
const config = { host: '127.0.0.1', port: 55439, user: 'pedidos_test', database: 'postgres', connectionTimeoutMillis: 5000 };
const name = `inga_impresion_test_${Date.now()}`;
const admin = new Client(config);
let pool, created = false;
async function main() {
  await admin.connect();
  assert.equal((await admin.query('SELECT current_user AS usuario')).rows[0].usuario, 'pedidos_test');
  await admin.query(`CREATE DATABASE "${name}"`); created = true;
  pool = new Pool({ ...config, database: name });
  const setup = await pool.connect();
  try {
    await setup.query(fs.readFileSync(path.join(root, 'database_sql/database.sql'), 'utf8'));
    await setup.query('COMMIT');
    const installer = fs.readFileSync(path.join(root, 'database_sql/instalar_inventario.sql'), 'utf8');
    await setup.query(installer.replace(/^\\set.*$/gm, '').replace(/^\\ir (.+)$/gm,
      (_, file) => fs.readFileSync(path.join(root, 'database_sql', file.trim()), 'utf8')));
    const migration = fs.readFileSync(path.join(root, 'database_sql/migraciones/20261003_impresion_comandas.sql'), 'utf8');
    await setup.query(migration); await setup.query(migration);
  } finally { setup.release(); }
  const q = async (sql, params = []) => (await pool.query(sql, params)).rows;
  const insert = async (table, data) => {
    const columns = Object.keys(data);
    return (await q(`INSERT INTO ${table} (${columns.join(',')}) VALUES (${columns.map((_, i) => `$${i+1}`).join(',')}) RETURNING id`, Object.values(data)))[0].id;
  };
  const empresa = await insert('gen_empresa', { ruc: '20000000001', razon_social: 'Print Test' });
  const sucursal = await insert('gen_sucursal', { id_empresa: empresa, codigo: 'TEST', nombre: 'Test' });
  const trabajador = await insert('pla_trabajador', { nombres: 'Mozo', apellidos: 'Test', email: 'print@test.local' });
  const usuario = await insert('auth_usuario', { username: 'print_test', password_hash: 'test', id_trabajador: trabajador });
  const estacion = await insert('gen_estacion', { id_sucursal: sucursal, codigo: 'COC', nombre: 'Cocina', tipo_estacion: 1, impresora_ip: '192.168.1.101' });
  const otra = await insert('gen_estacion', { id_sucursal: sucursal, codigo: 'BAR', nombre: 'Barra', tipo_estacion: 2, impresora_ip: '192.168.1.102' });
  const categoria = await insert('pro_categoria', { codigo: 'TEST', nombre: 'Test' });
  const sub = await insert('pro_subcategoria', { id_categoria: categoria, codigo: 'TEST', nombre: 'Test' });
  const unidad = (await q('SELECT id FROM pro_unidad_medida LIMIT 1'))[0].id;
  const producto = await insert('pro_producto', { id_subcategoria: sub, id_unidad_medida: unidad, id_estacion: estacion, codigo_interno: 'PLATO', nombre: 'Pollo', tipo_producto: 3, controla_stock: false, precio_venta: 10 });
  const pedido = await insert('ven_pedido', { id_sucursal: sucursal, id_mozo: usuario, tipo_pedido: 2, codigo: 'PRINT-1' });
  const tx = await pool.connect();
  let comanda;
  try {
    await tx.query('BEGIN');
    comanda = (await tx.query('INSERT INTO ven_comanda(id_pedido,id_estacion,numero) VALUES($1,$2,1) RETURNING id', [pedido,estacion])).rows[0].id;
    await tx.query(`INSERT INTO ven_pedido_detalle(id_pedido,id_comanda,id_producto,cantidad,precio_unitario,monto_subtotal,observacion)
      VALUES($1,$2,$3,2,10,20,'Sin sal')`, [pedido,comanda,producto]);
    assert.equal((await tx.query('SELECT count(*)::int AS n FROM ven_impresion_trabajo')).rows[0].n, 0);
    await tx.query('COMMIT');
  } finally { tx.release(); }
  const snapshot = (await q('SELECT contenido FROM ven_impresion_trabajo WHERE id_comanda=$1', [comanda]))[0].contenido;
  assert.equal(snapshot.items[0].nombre_producto, 'Pollo');
  assert.equal(snapshot.items[0].observacion, 'Sin sal');
  await q("UPDATE pro_producto SET nombre='Otro nombre' WHERE id=$1", [producto]);
  assert.equal((await q('SELECT contenido FROM ven_impresion_trabajo WHERE id_comanda=$1', [comanda]))[0].contenido.items[0].nombre_producto, 'Pollo');
  const service = new ImpresionLogic(new ImpresionModel({ query: (sql, params) => pool.query(sql, params) }));
  assert.equal(await service.tomar([Number(otra)], randomUUID()), null);
  const owner = randomUUID();
  const attempts = await Promise.all(Array.from({ length: 8 }, () => service.tomar([Number(estacion)], owner)));
  assert.equal(attempts.filter(Boolean).length, 1);
  assert.equal(attempts.find(Boolean).host, '192.168.1.101');
  await assert.rejects(() => service.confirmar(comanda, randomUUID(), true), /pertenece/);
  await assert.rejects(() => service.resolver(comanda, false), /sigue activo/);
  await service.confirmar(comanda, owner, false, 'Impresora desconectada');
  assert.equal(await service.tomar([Number(estacion)], randomUUID()), null);
  assert.equal((await service.pendientes([Number(estacion)]))[0].estado, 'revision');
  await service.resolver(comanda, false);
  const newOwner = randomUUID();
  assert.equal((await service.tomar([Number(estacion)], newOwner)).id, comanda);
  await assert.rejects(() => service.confirmar(comanda, owner, true), /pertenece/);
  await service.confirmar(comanda, newOwner, true);
  await service.confirmar(comanda, newOwner, true); // ACK idempotente.
  assert.deepEqual(await service.pendientes([Number(estacion)]), []);
  assert.equal(await service.tomar([Number(estacion)], randomUUID()), null);
  assert.ok((await q('SELECT fecha_impresion FROM ven_comanda WHERE id=$1', [comanda]))[0].fecha_impresion);
  const cancelled = await insert('ven_comanda', { id_pedido: pedido, id_estacion: estacion, numero: 2 });
  await q('UPDATE ven_comanda SET estado=0 WHERE id=$1', [cancelled]);
  assert.equal(await service.tomar([Number(estacion)], randomUUID()), null);
  const rollback = await pool.connect();
  try {
    await rollback.query('BEGIN');
    await rollback.query('INSERT INTO ven_comanda(id_pedido,id_estacion,numero) VALUES($1,$2,3)', [pedido,estacion]);
    await rollback.query('ROLLBACK');
    assert.equal((await q('SELECT count(*)::int AS n FROM ven_impresion_trabajo'))[0].n, 2);
  } finally { rollback.release(); }
  console.log('OK: snapshot al commit, rollback, aislamiento por estación, 8 reclamaciones concurrentes, propietario, revisión, reintento y ACK idempotente.');
}
main().catch((error) => { console.error(error); process.exitCode = 1; }).finally(async () => {
  if (pool) await pool.end();
  if (created) await admin.query(`DROP DATABASE "${name}" WITH (FORCE)`);
  await admin.end();
});
