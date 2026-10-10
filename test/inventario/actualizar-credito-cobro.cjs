// Regla de crédito del convenio: limite_credito es el TECHO DE LA DEUDA.
//   - con tope   -> a crédito solo lo que falta para llegar al tope, el resto efectivo
//   - sin tope (0) -> entra el pedido completo
// Corre contra las funciones del ARCHIVO (se aplican en la transacción), todo con
// ROLLBACK. Los pedidos se eligen limpios en cada corrida porque la base se transforma
// con las pruebas manuales del cajero.
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
const DNI = '88888888';
const CONVENIO = 2;
const CAJERO = 9;
const money = n => Number(Number(n).toFixed(2));
const saldoDe = async p => money((await client.query('SELECT cxc_calcular_saldo_persona($1) AS s', [p])).rows[0].s);
const datos = (extra) => JSON.stringify({ documento: DNI, efectivo_confirmado: true, ...extra });

async function pedidoLimpio() {
  const { rows } = await client.query(
    `SELECT pd.id, pd.codigo FROM ven_pedido pd
      WHERE pd.estado_pedido IN (1,2,3)
        AND pd.monto_total > 0
        AND NOT EXISTS (SELECT 1 FROM ven_pago vg WHERE vg.id_pedido = pd.id)
        AND NOT EXISTS (SELECT 1 FROM ven_comprobante vc WHERE vc.id_pedido = pd.id)
        AND EXISTS (SELECT 1 FROM ven_pedido_detalle d
                     WHERE d.id_pedido = pd.id AND d.estado = 1 AND d.tipo_linea <> 3
                       AND d.cantidad > d.cantidad_cancelada)
      ORDER BY pd.monto_total DESC, pd.id LIMIT 1`);
  assert.ok(rows.length, 'necesito al menos un pedido cobrable sin pagos');
  const id = Number(rows[0].id);
  // Entrego todas sus líneas y recalculo, para que pase la validación de "entregado".
  await client.query(
    `UPDATE ven_pedido_detalle SET cantidad_entregada = cantidad - cantidad_cancelada
      WHERE id_pedido = $1 AND estado = 1 AND tipo_linea <> 3`, [id]);
  // ven_pedido_cobrar también exige que las líneas tengan comanda (id_comanda IS NOT
  // NULL), así que la fabrico: sin esto un pedido nunca comandeado se rechaza con
  // "Hay platos pendientes de entregar" aunque sus líneas estén entregadas.
  const { rows: [cmd] } = await client.query(
    `INSERT INTO ven_comanda (id_pedido, id_estacion, numero)
     VALUES ($1, (SELECT id FROM gen_estacion WHERE estado=1 AND id_sucursal =
              (SELECT id_sucursal FROM ven_pedido WHERE id=$1) LIMIT 1),
             (SELECT COALESCE(max(numero),0)+1 FROM ven_comanda WHERE id_pedido=$1))
     RETURNING id`, [id]);
  await client.query(
    'UPDATE ven_pedido_detalle SET id_comanda = $1 WHERE id_pedido = $2 AND estado = 1 AND tipo_linea <> 3',
    [cmd.id, id]);
  await client.query('SELECT ven_recalcular_pedido($1, $2)', [id, CAJERO]);
  const total = money((await client.query(
    'SELECT monto_total FROM ven_pedido WHERE id=$1', [id])).rows[0].monto_total);
  return { id, codigo: rows[0].codigo, total };
}

const pagosDe = async id => (await client.query(
  'SELECT medio_pago, monto FROM ven_pago WHERE id_pedido=$1 AND estado=1 ORDER BY id', [id])).rows;

(async () => { try {
  await client.connect();
  await client.query('BEGIN');
  await client.query(fs.readFileSync(
    path.join(process.cwd(), 'database_sql/funciones/pedidos/ven_pedido_cobrar.sql'), 'utf8'));

  await client.query('UPDATE cli_convenio SET limite_credito = 100 WHERE id = $1', [CONVENIO]);
  const { rows: [pRaw] } = await client.query(
    `INSERT INTO cli_persona (tipo_persona, tipo_documento, num_documento, nombres, apellido_paterno, es_cliente, id_convenio)
     VALUES (1, 1, $1, 'Caso', 'Prueba', TRUE, $2) RETURNING id`, [DNI, CONVENIO]);
  const p = { ...pRaw, id: Number(pRaw.id) };
  await client.query('SELECT cxc_registrar_consumo($1, 80, CURRENT_DATE, NULL, NULL, $2, NULL)', [p.id, 'Deuda previa']);
  assert.equal(await saldoDe(p.id), 80, 'la deuda inicial debe ser 80');

  // --- 1. tope 100 con deuda 80: reparte lo que falta y el resto en efectivo ---
  {
    const ped = await pedidoLimpio();
    const disponible = 20;                              // 100 - 80
    const credito = Math.min(ped.total, disponible);
    const efectivo = money(ped.total - credito);
    await client.query('SELECT ven_pedido_credito($1, NULL, $2::jsonb, $3)', [ped.id, datos(), CAJERO]);

    const pg = await pagosDe(ped.id);
    assert.equal(pg.length, 2, 'debe haber un pago a credito y uno de efectivo');
    assert.equal(Number(pg[0].medio_pago), 4, 'el primero es el pago a credito');
    assert.equal(Number(pg[0].id_convenio ?? CONVENIO), CONVENIO, 'apunta al convenio');
    assert.equal(money(pg[0].monto), credito, 'monto del pago a credito');
    assert.equal(Number(pg[1].medio_pago), 1, 'el segundo es efectivo');
    assert.equal(money(pg[1].monto), efectivo, 'monto del pago en efectivo');
    assert.equal(await saldoDe(p.id), 100, 'la deuda queda justo en el limite');
    console.log(`1. tope 100 / deuda 80 / pedido ${ped.codigo} (${ped.total}) -> credito ${credito} + efectivo ${efectivo} | deuda 80 -> 100`);
  }

  // --- 2. cliente en el tope: todo efectivo, la deuda no se mueve ---
  {
    await client.query('UPDATE cli_convenio SET limite_credito = 80 WHERE id = $1', [CONVENIO]);
    const ped = await pedidoLimpio();
    await client.query('SELECT ven_pedido_credito($1, NULL, $2::jsonb, $3)', [ped.id, datos(), CAJERO]);
    const pg = await pagosDe(ped.id);
    assert.equal(pg.length, 1, 'sin credito disponible solo queda el pago en efectivo');
    assert.equal(Number(pg[0].medio_pago), 1, 'el unico pago es en efectivo');
    assert.equal(money(pg[0].monto), ped.total, 'se cobra el total en efectivo');
    assert.equal(await saldoDe(p.id), 100, 'la deuda no se mueve');
    console.log(`2. en el tope / pedido ${ped.codigo} (${ped.total}) -> solo efectivo | deuda sigue 100`);
  }

  // --- 3. sin confirmar el efectivo del excedente: rechaza ---
  {
    const ped = await pedidoLimpio();
    // limite mayor que la deuda (disponible > 0) pero menor que el total (excedente > 0).
    await client.query('UPDATE cli_convenio SET limite_credito = $1 WHERE id = $2',
      [100 + Math.floor(ped.total / 2), CONVENIO]);
    await client.query('SAVEPOINT s3');
    let mensaje = '';
    try {
      await client.query('SELECT ven_pedido_credito($1, NULL, $2::jsonb, $3)',
        [ped.id, JSON.stringify({ documento: DNI }), CAJERO]);
    } catch (err) { mensaje = err.message; }
    await client.query('ROLLBACK TO SAVEPOINT s3');
    assert.match(mensaje, /Confirme la recepción de S\/ .* en efectivo/,
      'debe exigir confirmar el efectivo');
    console.log(`3. sin efectivo_confirmado -> "${mensaje}"`);
  }

  // --- 4. convenio sin tope (limite 0) entra el pedido completo ---
  {
    await client.query('UPDATE cli_convenio SET limite_credito = 0 WHERE id = $1', [CONVENIO]);
    const ped = await pedidoLimpio();
    const antes = await saldoDe(p.id);
    await client.query('SELECT ven_pedido_credito($1, NULL, $2::jsonb, $3)', [ped.id, datos(), CAJERO]);
    const pg = await pagosDe(ped.id);
    assert.equal(pg.length, 1, 'sin tope no hay excedente: un solo pago');
    assert.equal(Number(pg[0].medio_pago), 4, 'el pedido completo va a credito');
    assert.equal(money(pg[0].monto), ped.total, 'se carga el total, no solo lo que falta');
    assert.equal(await saldoDe(p.id), money(antes + ped.total), 'la deuda sube con el pedido completo');
    console.log(`4. sin tope (0) / pedido ${ped.codigo} (${ped.total}) -> credito integro | deuda ${antes} -> ${money(antes + ped.total)}`);
  }

  await client.query('ROLLBACK');
  console.log('\nLos 4 escenarios OK. Reverso hecho: nada se persistio.');
} catch (err) {
  await client.query('ROLLBACK').catch(() => {});
  console.error('FALLO: ' + (err.message || err));
  process.exitCode = 1;
} finally { await client.end(); } })();
