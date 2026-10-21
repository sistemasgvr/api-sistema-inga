require('dotenv').config({ quiet: true });
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
// La BD tenía versiones que solo aceptaban el estado 2: tras la precuenta (estado 3)
// no se podía entregar, cancelar ni marcar listo un plato y el pedido quedaba trabado.
(async () => {
  try {
    await client.connect();
    await client.query('BEGIN');
    for (const file of ['pedidos/ven_pedido_entregar.sql', 'pedidos/ven_pedido_anular_item.sql', 'pedidos/ven_pedido_preparacion.sql']) {
      await client.query(fs.readFileSync(path.join(__dirname, '../../database_sql/funciones', file), 'utf8'));
    }
    await client.query('COMMIT');
    console.log('Funciones actualizadas: con la precuenta pedida se puede entregar, cancelar y marcar listo. No se modificaron pedidos ni existencias.');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('No se pudo actualizar:', error.code || error.name);
    process.exitCode = 1;
  } finally { await client.end(); }
})();
