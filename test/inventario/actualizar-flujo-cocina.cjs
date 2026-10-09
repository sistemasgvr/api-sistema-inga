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
(async () => {
  try {
    await client.connect();
    await client.query('BEGIN');
    for (const file of ['produccion/prod_preparar.sql', 'pedidos/ven_pedido_preparacion.sql']) {
      await client.query(fs.readFileSync(path.join(__dirname, '../../database_sql/funciones', file), 'utf8'));
    }
    await client.query('COMMIT');
    console.log('Funciones actualizadas: iniciar deja En preparación; Plato listo usa estado 4. No se modificaron pedidos ni existencias.');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('No se pudo actualizar:', error.code || error.name);
    process.exitCode = 1;
  } finally { await client.end(); }
})();