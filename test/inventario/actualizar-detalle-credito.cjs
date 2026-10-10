// Flujo completo del estado de cuenta: detalle de ítems + corrección de crédito.
// Corre contra las funciones del ARCHIVO (se aplican en la transacción), todo con
// ROLLBACK al final.
require('dotenv').config({ quiet: true });
const assert = require('node:assert/strict');
const { Client } = require('pg');
const fs = require('node:fs');
const path = require('node:path');
const e = process.env;
const client = new Client({
  ...(e.DATABASE_URL ? { connectionString: e.DATABASE_URL } : {
    host: e.DB_HOST, port: Number(e.DB_PORT || 5432), user: e.DB_USER,
    password: e.DB_PASSWORD, database: e.DB_NAME,
  }),
  ssl: e.DB_SSL === 'true' || e.DATABASE_URL?.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
  connectionTimeoutMillis: 10000,
});
const DNI = '77777777';
const CAJERO = 9;
const money = n => Number(Number(n).toFixed(2));
const saldoDe = async p => money((await client.query('SELECT cxc_calcular_saldo_persona($1) AS s', [p])).rows[0].s);
const datos = () => JSON.stringify({ documento: DNI, efectivo_confirmado: true });

(async () => { try {
  await client.connect();
  await client.query('BEGIN');
  const dir = path.join(process.cwd(), 'database_sql/funciones');
  for (const f of ['cuentas-por-cobrar/cxc_registrar_abono.sql',
                   'cuentas-por-cobrar/cxc_listar_movimientos.sql',
                   'cuentas-por-cobrar/cxc_obtener_estado_cuenta.sql']) {
    await client.query(fs.readFileSync(path.join(dir, f), 'utf8'));
  }
  console.log('Funciones del archivo cargadas.\n');

  // Convenio sin tope -> el pedido completo entra a crédito (rama A que elegiste).
  const { rows: [c] } = await client.query(
    `INSERT INTO cli_convenio (codigo, nombre, id_condicion_pago, limite_credito, corte_quincenal)
     VALUES ('TEST-DTL', 'Prueba Detalle', (SELECT id FROM gen_condicion_pago LIMIT 1), 0, TRUE)
     RETURNING id`);
  const { rows: [pRaw] } = await client.query(
    `INSERT INTO cli_persona (tipo_persona, tipo_documento, num_documento, nombres, apellido_paterno, es_cliente, id_convenio)
     VALUES (1, 1, $1, 'Detalle', 'Prueba', TRUE, $2) RETURNING id`, [DNI, c.id]);
  const p = { ...pRaw, id: Number(pRaw.id) };

  // Elijo pedidos limpios en vez de fijar ids: la base se transforma con las pruebas
  // manuales del cajero y un id fijo deja de estar disponible tarde o temprano.
  // Pido total >= 100 porque los abonos de la prueba son de 10 y 50, y el backend
  // rechaza un abono que supere la deuda (y lo devuelve como error, sin lanzar).
  const pedidosLimpios = async (n) => (await client.query(
    `SELECT pd.id, pd.codigo FROM ven_pedido pd
      WHERE pd.estado_pedido IN (1,2,3)
        AND pd.monto_total >= 100
        AND NOT EXISTS (SELECT 1 FROM ven_pago vg WHERE vg.id_pedido = pd.id)
        AND NOT EXISTS (SELECT 1 FROM ven_comprobante vc WHERE vc.id_pedido = pd.id)
        AND EXISTS (SELECT 1 FROM ven_pedido_detalle d
                     WHERE d.id_pedido = pd.id AND d.estado = 1 AND d.tipo_linea <> 3
                       AND d.cantidad > d.cantidad_cancelada)
      ORDER BY pd.id LIMIT $1`, [n])).rows;

  const libres = await pedidosLimpios(2);
  assert.ok(libres.length >= 2, 'necesito al menos dos pedidos cobrables sin pagos');
  // pg devuelve los BIGINT como texto; sin Number() las comparaciones con === fallan.
  const [obj, otro] = libres.map((o) => ({ ...o, id: Number(o.id) }));
  const PED = obj.id;

  await client.query(
    `UPDATE ven_pedido_detalle SET cantidad_entregada = cantidad - cantidad_cancelada
      WHERE id_pedido = $1 AND estado = 1 AND tipo_linea <> 3`, [PED]);
  await client.query('SELECT ven_recalcular_pedido($1, $2)', [PED, CAJERO]);
  const total = money((await client.query(
    'SELECT monto_total FROM ven_pedido WHERE id=$1', [PED])).rows[0].monto_total);
  await client.query('SELECT ven_pedido_credito($1, NULL, $2::jsonb, $3)', [PED, datos(), CAJERO]);
  assert.equal(await saldoDe(p.id), total, 'sin tope, todo el total va a crédito');
  console.log(`1. Venta a crédito sin tope: pedido ${PED} (${obj.codigo}), total ${total}, saldo ${total}`);

  // El estado de cuenta debe traer el detalle de ítems del pedido.
  const cuenta = (await client.query(
    'SELECT cxc_obtener_estado_cuenta($1) AS c', [p.id])).rows[0].c.registro;
  const cargo = cuenta.movimientos.find(m => m.id_pedido === PED);
  assert.ok(cargo, `el cargo del pedido ${PED} debe estar en el estado de cuenta`);
  // El front abre la corrección con este id para preseleccionar el cliente; sin él el
  // modal arranca sin cliente y el guardado rebota con "Selecciona al cliente".
  assert.equal(cargo.id_persona, p.id, 'el movimiento debe traer id_persona');
  assert.ok(cuenta.movimientos.every(m => typeof m.id_persona === 'number'),
    'ningún movimiento puede venir sin id_persona');
  assert.ok(cargo.detalle_pedido, 'detalle_pedido no debe venir vacío');
  // "3x Arroz, 1x Gaseosa": cada pieza debe ser "<cantidad>x <producto>".
  const piezas = cargo.detalle_pedido.split(', ');
  const nombres = [];
  for (const pieza of piezas) {
    const m = /^(\d+(\.\d+)?)x (.+)$/.exec(pieza);
    assert.ok(m, `pieza con formato inválido: "${pieza}"`);
    nombres.push(m[3]);
  }
  // El pedido tiene el mismo producto en varias líneas: debe salir UNA vez, con la
  // cantidad sumada, no repetido.
  assert.equal(new Set(nombres).size, nombres.length,
    `el detalle no debe repetir productos: ${cargo.detalle_pedido}`);
  assert.equal(piezas.length, cargo.detalle_pedido.split(', ').length, 'formato estable');
  console.log(`2. Estado de cuenta: ${piezas.length} ítems -> "${cargo.detalle_pedido}"`);

  // El listado general también, y con el mismo detalle.
  const lista = (await client.query(
    'SELECT cxc_listar_movimientos(\'\', 50, 0, $1) AS r', [p.id])).rows[0].r;
  const cargoLista = lista.registros.find(m => m.id_pedido === PED);
  assert.ok(cargoLista, 'el listado general debe traer el cargo del pedido');
  assert.equal(cargoLista.detalle_pedido, cargo.detalle_pedido, 'ambos listados deben traer el mismo detalle');

  // Un abono manual NO lleva detalle de pedido. Ojo: estas funciones devuelven
  // {error} en vez de lanzar, así que un rechazo silencioso aparecería más adelante
  // como un undefined. Chequeo el error en cada llamada.
  const abonoManual = (await client.query(
    'SELECT cxc_registrar_abono($1, 10, CURRENT_DATE, $2, NULL) AS r', [p.id, 'Abono normal'])).rows[0].r;
  assert.ok(!abonoManual.error, `el abono manual no debe fallar: ${abonoManual.error}`);
  const cuenta2 = (await client.query(
    'SELECT cxc_obtener_estado_cuenta($1) AS c', [p.id])).rows[0].c.registro;
  const abono = cuenta2.movimientos.find(m => m.tipo_movimiento === 2);
  assert.ok(abono, 'el abono manual debe aparecer en el estado de cuenta');
  assert.ok(!abono.detalle_pedido, 'un abono manual no debe traer detalle de pedido');
  console.log('3. Abono manual sin detalle de pedido: correcto');

  // Corrección: abono vinculado al pedido, con la observación autocompletada.
  const antes = await saldoDe(p.id);
  const alta = (await client.query(
    'SELECT cxc_registrar_abono($1, $2, CURRENT_DATE, NULL, NULL, $3) AS r', [p.id, 50, PED])).rows[0].r;
  assert.ok(!alta.error, `la corrección no debe fallar: ${alta.error}`);
  // cxc_registrar_abono devuelve el movimiento envuelto en { registro }, igual que el
  // resto del módulo (es lo que espera mapSingleResult en el backend).
  const res = alta.registro;
  assert.match(res.observacion, /Corrección de crédito/, 'la observación se autocompleta');
  assert.equal(res.id_pedido, PED, 'el abono queda ligado al pedido');
  assert.equal(await saldoDe(p.id), money(antes - 50), 'la deuda baja por el monto corregido');
  console.log(`4. Corrección de 50: saldo ${antes} -> ${await saldoDe(p.id)} — "${res.observacion}"`);

  // El historial empareja cargo y corrección, y ambos muestran los ítems.
  const cuenta3 = (await client.query(
    'SELECT cxc_obtener_estado_cuenta($1) AS c', [p.id])).rows[0].c.registro;
  const corr = cuenta3.movimientos.find(m => m.tipo_movimiento === 2 && m.id_pedido === PED);
  assert.ok(corr, 'el abono de corrección debe aparecer en el historial');
  assert.equal(corr.detalle_pedido, cargo.detalle_pedido, 'la corrección muestra los mismos ítems');
  console.log(`5. Historial empareja cargo y corrección del pedido ${PED}`);

  // Validación: el pedido no existe.
  const malo = (await client.query(
    'SELECT cxc_registrar_abono($1, 10, CURRENT_DATE, NULL, NULL, 999999) AS r', [p.id])).rows[0].r;
  assert.match(malo.error, /no existe/, 'un pedido inexistente debe rechazarse');
  console.log(`6. Pedido inexistente rechazado: "${malo.error}"`);

  // Validación: el pedido existe pero no es de este cliente.
  const ajeno = (await client.query(
    'SELECT cxc_registrar_abono($1, 10, CURRENT_DATE, NULL, NULL, $2) AS r', [p.id, otro.id])).rows[0].r;
  assert.match(ajeno.error, /no está vinculado a este cliente/, 'un pedido ajeno debe rechazarse');
  console.log(`7. Pedido ajeno (${otro.codigo}) rechazado: "${ajeno.error}"`);

  await client.query('ROLLBACK');
  console.log('\nTodo verificado. Reverso hecho: nada se persistio.');
} catch (err) {
  await client.query('ROLLBACK').catch(() => {});
  console.error('FALLO: ' + (err.message || err));
  process.exitCode = 1;
} finally { await client.end(); } })();
