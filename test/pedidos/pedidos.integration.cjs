/* Prueba real en una instancia LOCAL temporal con usuario pedidos_test.
 * No lee .env. Crea y elimina exclusivamente su propia base inga_pedidos_test_<timestamp>.
 * Iniciar previamente un clúster de pruebas en 127.0.0.1:55439 (ver docs/pedidos.md).
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Client, Pool } = require('pg');
const root = path.resolve(__dirname, '../..');
const config = { host: '127.0.0.1', port: 55439, user: 'pedidos_test', database: 'postgres', connectionTimeoutMillis: 5000 };
const name = `inga_pedidos_test_${Date.now()}`;
const admin = new Client(config);
let pool;
let created = false;
let checks = 0;
const check = (actual, expected) => { assert.deepEqual(actual, expected); checks++; };
const rejects = async (fn, pattern) => { await assert.rejects(fn, pattern); checks++; };

async function main() {
  await admin.connect();
  assert.equal((await admin.query('SELECT current_user AS usuario')).rows[0].usuario, 'pedidos_test');
  await admin.query(`CREATE DATABASE "${name}"`);
  created = true;
  pool = new Pool({ ...config, database: name, max: 5 });
  const setup = await pool.connect();
  try {
    await setup.query(fs.readFileSync(path.join(root, 'database_sql/database.sql'), 'utf8'));
    // El esquema base contiene BEGIN; se confirma antes del instalador del módulo.
    await setup.query('COMMIT');
    const installer = fs.readFileSync(path.join(root, 'database_sql/instalar_pedidos.sql'), 'utf8');
    const sql = installer.replace(/^\\set.*$/gm, '').replace(/^\\ir (.+)$/gm, (_, file) => fs.readFileSync(path.join(root, 'database_sql', file.trim()), 'utf8'));
    await setup.query(sql);
    await setup.query(sql); // La instalación se puede repetir.
  } finally { setup.release(); }
  const q = async (sql, params = []) => (await pool.query(sql, params)).rows;
  const insert = async (table, data) => {
    const columns = Object.keys(data);
    return (await q(`INSERT INTO ${table} (${columns.join(',')}) VALUES (${columns.map((_, i) => `$${i + 1}`).join(',')}) RETURNING id`, Object.values(data)))[0].id;
  };
  const empresa = await insert('gen_empresa', { ruc: '20000000001', razon_social: 'Pruebas' });
  const sucursal = await insert('gen_sucursal', { id_empresa: empresa, codigo: 'TEST', nombre: 'Pruebas' });
  const otraSucursal = await insert('gen_sucursal', { id_empresa: empresa, codigo: 'OTRA', nombre: 'Otra' });
  const usuario = await insert('auth_usuario', { username: 'admin_test', email: 'admin@test.local', password_hash: 'test', nombres: 'Admin', apellidos: 'Test' });
  const mozo = await insert('auth_usuario', { username: 'mozo_test', email: 'mozo@test.local', password_hash: 'test', nombres: 'Mozo', apellidos: 'Test' });
  const rol = (await q("SELECT id FROM auth_rol WHERE codigo = 'ADMIN'"))[0].id;
  await insert('auth_usuario_rol', { id_usuario: usuario, id_rol: rol });
  const caja = await insert('caj_caja', { id_sucursal: sucursal, codigo: 'CAJA', nombre: 'Caja' });
  const turno = await insert('caj_turno', { id_caja: caja, id_cajero: usuario });
  const salon = await insert('ven_salon', { id_sucursal: sucursal, codigo: 'SALON', nombre: 'Salón' });
  const mesa = await insert('ven_mesa', { id_salon: salon, codigo: 'M1' });
  const almacen = await insert('gen_almacen', { id_sucursal: sucursal, codigo: 'COC', nombre: 'Cocina', tipo_almacen: 2 });
  const cocina = await insert('gen_estacion', { id_sucursal: sucursal, codigo: 'COC', nombre: 'Cocina', tipo_estacion: 1 });
  const barra = await insert('gen_estacion', { id_sucursal: sucursal, codigo: 'BAR', nombre: 'Barra', tipo_estacion: 2 });
  const categoria = await insert('pro_categoria', { codigo: 'TEST', nombre: 'Pruebas' });
  const subcategoria = await insert('pro_subcategoria', { id_categoria: categoria, codigo: 'TEST', nombre: 'Pruebas' });
  const kg = (await q("SELECT id FROM pro_unidad_medida WHERE codigo = 'KG'"))[0].id;
  const gramos = (await q("SELECT id FROM pro_unidad_medida WHERE codigo = 'G'"))[0].id;
  const product = (codigo, data = {}) => insert('pro_producto', { id_subcategoria: subcategoria, id_unidad_medida: kg, id_estacion: cocina, id_almacen_stock: almacen, codigo_interno: codigo, nombre: codigo, tipo_producto: 2, controla_stock: true, precio_venta: 11.80, ...data });
  const insumo = await product('INSUMO');
  const bebida = await product('BEBIDA', { tipo_producto: 6, id_estacion: barra, afecto_igv: false, precio_venta: 10 });
  const plato = await product('PLATO', { tipo_producto: 3, controla_stock: false });
  await insert('alm_producto_stock', { id_almacen: almacen, id_producto: insumo, stock_actual: 10, costo_promedio: 5 });
  await insert('alm_producto_stock', { id_almacen: almacen, id_producto: bebida, stock_actual: 10, costo_promedio: 3 });
  const receta = await insert('pro_receta', { id_producto: plato, rendimiento_porciones: 2 });
  const ri = await insert('pro_receta_insumo', { id_receta: receta, id_producto_insumo: insumo, cantidad: 200, id_unidad_medida: gramos, porcentaje_merma: 10 });
  const adicional = await insert('pro_adicional', { id_producto: plato, nombre: 'Extra', precio_adicional: 1.18, id_producto_insumo: insumo, cantidad_insumo: 50, id_unidad_medida: gramos });
  const call = async (accion, id = null, item = null, datos = {}, actor = usuario) => (await q(`SELECT ven_pedido_${accion}($1,$2,$3::jsonb,$4) AS result`, [id, item, JSON.stringify(datos), actor]))[0].result.registro;
  const openData = { tipo_pedido: 1, id_mesa: Number(mesa), id_mozo: Number(mozo), id_turno: Number(turno), tasa_igv: 18 };
  const abrir = () => call('abrir', null, null, openData);
  const llevar = () => call('abrir', null, null, { ...openData, tipo_pedido: 2, id_mesa: null, id_sucursal: Number(sucursal) });
  const anulacion = { id_usuario_autoriza: Number(usuario), motivo: 'Prueba de reverso' };
  const stock = async id => Number((await q('SELECT stock_actual FROM alm_producto_stock WHERE id_producto = $1', [id]))[0].stock_actual);
  const estadoMesa = async () => (await q('SELECT estado_mesa FROM ven_mesa WHERE id = $1', [mesa]))[0].estado_mesa;
  const obtener = async id => (await q('SELECT ven_obtener_pedido($1) AS r', [id]))[0].r.registro;
  const agregar = (id, producto, cantidad = 1, extras = {}) => call('agregar_item', id, null, { id_producto: Number(producto), cantidad, ...extras });

  // Aperturas simultáneas: solo una gana y la mesa queda ocupada.
  const concurrentes = await Promise.allSettled([abrir(), abrir()]);
  check(concurrentes.filter(r => r.status === 'fulfilled').length, 1);
  check(concurrentes.filter(r => r.status === 'rejected').length, 1);
  let pedido = concurrentes.find(r => r.status === 'fulfilled').value;
  check(await estadoMesa(), 2);
  await rejects(() => call('comandar', pedido.id), /sin ítems/);
  await rejects(() => agregar(pedido.id, plato, 0), /cantidad/);
  await rejects(() => call('abrir', null, null, { ...openData, tipo_pedido: 2, id_mesa: null, id_sucursal: Number(otraSucursal) }), /turno abierto/);

  pedido = await agregar(pedido.id, plato, 2, { adicionales: [{ id_adicional: Number(adicional) }] });
  const itemPlato = pedido.items[0].id;
  check([pedido.monto_subtotal, pedido.monto_igv, pedido.monto_total], [22, 3.96, 25.96]);
  pedido = await agregar(pedido.id, bebida);
  check([pedido.monto_subtotal, pedido.monto_igv, pedido.monto_total], [32, 5.76, 37.76]);
  check(await stock(insumo), 10);
  pedido = await call('editar_item', pedido.id, itemPlato, { cantidad: 3, observacion: 'Sin sal' });
  check(pedido.monto_total, 50.74);
  pedido = await call('editar_item', pedido.id, itemPlato, { cantidad: 2 });
  // Un producto modificado después de la venta no cambia el tratamiento del IGV guardado.
  await q('UPDATE pro_producto SET afecto_igv = false, precio_venta = 999 WHERE id = $1', [plato]);
  pedido = await call('editar_item', pedido.id, itemPlato, { observacion: 'Conservar precio' });
  check(pedido.monto_total, 37.76);
  await rejects(() => call('anular_item', pedido.id, itemPlato, anulacion, mozo), /usuario autenticado/);
  await rejects(() => call('anular_item', pedido.id, itemPlato, { ...anulacion, id_usuario_autoriza: Number(mozo) }, mozo), /ADMIN o CAJERO/);

  // Comandas separadas por estación, insumo: 200g / 2 * 2 * 1.1 + 50g * 2 = 0.32kg.
  pedido = await call('comandar', pedido.id);
  check(pedido.comandas.length, 2);
  check(pedido.estado_pedido, 2);
  check(await stock(insumo), 9.68);
  check(await stock(bebida), 9);
  check(pedido.items.every(i => i.stock_descontado), true);
  pedido = await call('comandar', pedido.id);
  check(pedido.comandas.length, 2);
  check(await stock(insumo), 9.68);
  await rejects(() => call('editar_item', pedido.id, itemPlato, { cantidad: 8 }), /pendientes/);
  await rejects(() => call('anular_item', pedido.id, itemPlato, anulacion), /stock descontado/);
  await rejects(() => call('estado', pedido.id, null, { estado_pedido: 4 }), /Transición/);

  // Segunda ronda y eliminación de ítems aún pendientes.
  pedido = await agregar(pedido.id, bebida);
  const pending = pedido.items.at(-1).id;
  await rejects(() => call('estado', pedido.id, null, { estado_pedido: 3 }), /pendientes/);
  pedido = await call('anular_item', pedido.id, pending, anulacion);
  check(pedido.items.at(-1).tipo_linea, 3);
  check(pedido.monto_total, 37.76);
  pedido = await agregar(pedido.id, bebida);
  pedido = await call('estado', pedido.id, null, { estado_pedido: 2 });
  check(pedido.comandas.length, 3);
  check(await stock(bebida), 8);
  pedido = await call('estado', pedido.id, null, { estado_pedido: 3 });
  check(await estadoMesa(), 3);
  await rejects(() => call('estado', pedido.id, null, { estado_pedido: 4 }), /pagos registrados/);

  // Cambiar receta después del descuento no altera la devolución original.
  await q('UPDATE pro_receta_insumo SET cantidad = 999 WHERE id = $1', [ri]);
  pedido = await call('anular', pedido.id, null, anulacion);
  check([pedido.estado_pedido, pedido.monto_total, await estadoMesa()], [5, 0, 1]);
  check(await stock(insumo), 10);
  check(await stock(bebida), 10);
  const reversos = (await q("SELECT count(*)::int AS n FROM alm_kardex WHERE documento_tipo = 'ANULACION_VENTA'"))[0].n;
  check(reversos, 3);
  await call('anular', pedido.id, null, anulacion);
  check((await q("SELECT count(*)::int AS n FROM alm_kardex WHERE documento_tipo = 'ANULACION_VENTA'"))[0].n, reversos);

  // Falla de stock: ni el otro producto ni las comandas/kardex se modifican.
  let insuficiente = await llevar();
  await agregar(insuficiente.id, insumo, 2);
  await agregar(insuficiente.id, bebida, 20);
  const ledgerBefore = (await q('SELECT count(*)::int AS n FROM alm_kardex'))[0].n;
  await rejects(() => call('comandar', insuficiente.id), /Stock insuficiente/);
  check(await stock(insumo), 10);
  check((await obtener(insuficiente.id)).comandas.length, 0);
  check((await q('SELECT count(*)::int AS n FROM alm_kardex'))[0].n, ledgerBefore);
  await call('anular', insuficiente.id, null, anulacion);

  // También revierte si el fallo ocurre DESPUÉS de modificar stock y kardex.
  const falloTardio = await llevar();
  await agregar(falloTardio.id, bebida);
  await q("CREATE FUNCTION test_fallar_comanda() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Fallo de comanda simulado'; END $$");
  await q('CREATE TRIGGER test_fallo BEFORE INSERT ON ven_comanda FOR EACH ROW EXECUTE FUNCTION test_fallar_comanda()');
  await rejects(() => call('comandar', falloTardio.id), /Fallo de comanda simulado/);
  check(await stock(bebida), 10);
  check((await q('SELECT count(*)::int AS n FROM alm_kardex'))[0].n, ledgerBefore);
  check((await obtener(falloTardio.id)).items[0].stock_descontado, false);
  await q('DROP TRIGGER test_fallo ON ven_comanda');
  await q('DROP FUNCTION test_fallar_comanda()');
  await call('anular', falloTardio.id, null, anulacion);

  // Dos pedidos compiten por el mismo stock: nunca queda saldo negativo.
  const a = await llevar(); const b = await llevar();
  await agregar(a.id, bebida, 6); await agregar(b.id, bebida, 6);
  const ventas = await Promise.allSettled([call('comandar', a.id), call('comandar', b.id)]);
  check(ventas.filter(r => r.status === 'fulfilled').length, 1);
  check(ventas.filter(r => r.status === 'rejected').length, 1);
  check(await stock(bebida), 4);
  await call('anular', a.id, null, anulacion); await call('anular', b.id, null, anulacion);
  check(await stock(bebida), 10);

  // PAGADO únicamente con pagos persistidos; libera mesa y no permite anulación de venta.
  let cobrado = await abrir();
  cobrado = await agregar(cobrado.id, bebida);
  await call('comandar', cobrado.id);
  await call('estado', cobrado.id, null, { estado_pedido: 3 });
  await insert('ven_pago', { id_pedido: cobrado.id, id_turno: turno, medio_pago: 1, monto: cobrado.monto_total });
  await rejects(() => call('anular', cobrado.id, null, anulacion), /pagos o comprobantes/);
  cobrado = await call('estado', cobrado.id, null, { estado_pedido: 4 });
  check([cobrado.estado_pedido, cobrado.monto_pagado, await estadoMesa()], [4, 11.80, 1]);
  await rejects(() => call('anular', cobrado.id, null, anulacion), /pagado/);

  // Reservas, recetas con sustituciones y pertenencia del ítem al pedido.
  await q('UPDATE pro_receta_insumo SET cantidad = 200, grupo_sustitucion = 1 WHERE id = $1', [ri]);
  const alternativo = await insert('pro_receta_insumo', { id_receta: receta, id_producto_insumo: bebida, cantidad: 0.5, id_unidad_medida: kg, grupo_sustitucion: 1 });
  const opcional = await insert('pro_receta_insumo', { id_receta: receta, id_producto_insumo: insumo, cantidad: 20, id_unidad_medida: gramos, es_opcional: true });
  let opciones = await llevar();
  await rejects(() => agregar(opciones.id, plato), /grupo obligatorio/);
  await rejects(() => agregar(opciones.id, plato, 1, { insumos_seleccionados: [Number(ri), Number(alternativo)] }), /grupo obligatorio/);
  await rejects(() => agregar(opciones.id, plato, 1, { insumos_seleccionados: [999999] }), /ajenos/);
  check((await obtener(opciones.id)).items.length, 0);
  opciones = await agregar(opciones.id, plato, 1, { insumos_seleccionados: [Number(ri), Number(opcional)] });
  await rejects(() => call('editar_item', opciones.id, itemPlato, { cantidad: 2 }), /Ítem no encontrado/);
  // 0.11kg de la alternativa elegida + 0.01kg del opcional (rendimiento = 2).
  opciones = await call('comandar', opciones.id);
  check(await stock(insumo), 9.88);
  const dobleAnulacion = await Promise.all([call('anular', opciones.id, null, anulacion), call('anular', opciones.id, null, anulacion)]);
  check(dobleAnulacion.every(p => p.estado_pedido === 5), true);
  check(await stock(insumo), 10);
  const reservado = await llevar();
  await agregar(reservado.id, bebida, 2);
  await q('UPDATE alm_producto_stock SET stock_reservado = stock_actual - 1 WHERE id_producto = $1', [bebida]);
  await rejects(() => call('comandar', reservado.id), /Stock insuficiente/);
  await q('UPDATE alm_producto_stock SET stock_reservado = 0 WHERE id_producto = $1', [bebida]);
  const stockPrevio = await stock(bebida);
  const dobleComanda = await Promise.all([call('comandar', reservado.id), call('comandar', reservado.id)]);
  check(dobleComanda.every(p => p.comandas.length === 1), true);
  check(await stock(bebida), stockPrevio - 2);
  await call('anular', reservado.id, null, anulacion);
  console.log(`Pedidos SQL: ${checks} comprobaciones correctas, incluida concurrencia real.`);
}

main().catch(error => { console.error(error); process.exitCode = 1; }).finally(async () => {
  if (pool) await pool.end();
  if (created) await admin.query(`DROP DATABASE "${name}"`);
  await admin.end();
});
