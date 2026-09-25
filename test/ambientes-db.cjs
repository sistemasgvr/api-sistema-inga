// Ejecutar: node --env-file=.env test/ambientes-db.cjs
// Usa tablas temporales y rollback: no cambia datos ni funciones del esquema público.
const { Client } = require('pg');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const assert = require('node:assert/strict');

const client = new Client({
  ...(process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {
    host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME,
  }),
  ssl: process.env.DB_SSL === 'true' || process.env.DATABASE_URL?.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
  connectionTimeoutMillis: 5000,
});

async function call(name, args = []) {
  const result = await client.query(`SELECT pg_temp.${name}(${args.map((_, i) => `$${i + 1}`).join(',')}) AS result`, args);
  return result.rows[0].result;
}

async function run() {
  await client.connect();
  await client.query('BEGIN');
  try {
    await client.query(`
      CREATE TEMP TABLE gen_sucursal (id BIGINT PRIMARY KEY, codigo TEXT, nombre TEXT, estado INTEGER);
      CREATE TEMP TABLE ven_salon (LIKE public.ven_salon INCLUDING ALL);
      CREATE TEMP TABLE ven_mesa (LIKE public.ven_mesa INCLUDING ALL);
      CREATE TEMP TABLE ven_pedido (id BIGINT, id_mesa BIGINT, estado INTEGER, estado_pedido INTEGER);
      SET LOCAL search_path TO pg_temp, public;
      INSERT INTO gen_sucursal VALUES (1, 'S1', 'Principal', 1), (2, 'S2', 'Inactiva', 0);
    `);
    // Usa el orden del instalador como fuente única; omite seeds de permisos.
    const sqlRoot = join(__dirname, '../database_sql');
    const installer = readFileSync(join(sqlRoot, 'instalar_ambientes.sql'), 'utf8');
    const sql = [...installer.matchAll(/^\\ir ((?:migraciones|funciones)\/[^\r\n]+)\r?$/gm)]
      .map((match) => readFileSync(join(sqlRoot, match[1]), 'utf8'))
      .join('\n')
      .replaceAll('CREATE OR REPLACE FUNCTION ven_', 'CREATE OR REPLACE FUNCTION pg_temp.ven_')
      .replaceAll('RETURN ven_obtener_', 'RETURN pg_temp.ven_obtener_');
    await client.query(sql);
    const create = await call('ven_guardar_salon', [null, { id_sucursal: 1, codigo: ' s01 ', nombre: 'Principal' }, 1]);
    assert.equal(create.registro.codigo, 'S01');
    const sid = create.registro.id;
    assert.equal(create.registro.ancho, 200);
    assert.ok((await call('ven_guardar_salon', [null, { id_sucursal: 1, codigo: 'S01', nombre: 'Duplicado' }, 1])).error);
    assert.ok((await call('ven_guardar_salon', [sid, { ancho: 0 }, 1])).error);
    assert.ok((await call('ven_guardar_salon', [null, { id_sucursal: 2, codigo: 'S02', nombre: 'Inactivo' }, 1])).error);
    const moved = await call('ven_guardar_salon', [sid, { posicion_x: 120, posicion_y: 60, ancho: 400, alto: 300 }, 2]);
    assert.equal(moved.registro.posicion_x, 120);
    assert.equal(moved.registro.nombre, 'Principal');
    assert.equal(moved.registro.id_usuario_modificacion, 2);
    const mesa = await call('ven_guardar_mesa', [null, { id_salon: sid, codigo: 'm1', capacidad_personas: 4 }, 1]);
    const mid = mesa.registro.id;
    assert.equal(mesa.registro.estado_mesa, 1);
    assert.ok((await call('ven_estado_salon', [sid, 0, 1])).error);
    assert.ok((await call('ven_guardar_mesa', [mid, { capacidad_personas: 0 }, 1])).error);
    assert.ok((await call('ven_guardar_mesa', [mid, { estado_mesa: 2 }, 1])).error);
    assert.ok((await call('ven_guardar_mesa', [null, { id_salon: sid, codigo: 'M1' }, 1])).error);
    await client.query('INSERT INTO ven_pedido VALUES (1, $1, 1, 1)', [mid]);
    assert.ok((await call('ven_guardar_mesa', [mid, { capacidad_personas: 6 }, 1])).error);
    assert.ok((await call('ven_estado_mesa', [mid, 0, 1])).error);
    await client.query('UPDATE ven_pedido SET estado_pedido = 4');
    assert.equal((await call('ven_guardar_mesa', [mid, { estado_mesa: 4 }, 1])).registro.estado_mesa, 4);
    assert.equal((await call('ven_estado_mesa', [mid, 0, 1])).registro.estado, 0);
    assert.equal((await call('ven_estado_salon', [sid, 0, 1])).registro.estado, 0);
    assert.ok((await call('ven_estado_mesa', [mid, 1, 1])).error);
    assert.equal((await call('ven_estado_salon', [sid, 1, 1])).registro.estado, 1);
    assert.equal((await call('ven_estado_mesa', [mid, 1, 1])).registro.estado, 1);
    assert.equal((await call('ven_listar_salones', [{ id_sucursal: 1, limite: 1, offset: 0 }])).total, 1);
    assert.equal((await call('ven_listar_salones', [{ id_sucursal: 2 }])).total, 0);
    assert.equal((await call('ven_listar_mesas', [{ id_salon: sid }])).total, 1);
    assert.equal((await call('ven_obtener_mesa', [999999])).registro, null);
    console.log('Ambientes DB: comprobaciones correctas; cambios revertidos.');
  } finally {
    await client.query('ROLLBACK');
    await client.end();
  }
}
run().catch(e => { console.error(e.code || '', e.message); process.exitCode = 1; });
