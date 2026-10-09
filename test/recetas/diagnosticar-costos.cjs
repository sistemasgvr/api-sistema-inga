// Solo lectura: compara los contratos instalados con los costos de inventario.
require('dotenv').config({ quiet: true });
const { Client } = require('pg');
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
    await client.query('BEGIN READ ONLY');
    const functions = await client.query(`SELECT proname, oid::regprocedure::text AS firma,
      position('AS costo_unitario' in pg_get_functiondef(oid)) > 0 AS expone_costo_unitario,
      position('costo_unitario_estimado' in pg_get_functiondef(oid)) > 0 AS expone_estimado,
      position('costo_total_calculado' in pg_get_functiondef(oid)) > 0 AS expone_total
      FROM pg_proc WHERE proname IN ('pro_listar_productos','pro_obtener_receta')`);
    console.log(JSON.stringify({funciones: functions.rows}));
    const costs = await client.query(`SELECT p.id,p.nombre,p.id_almacen_stock,p.costo_receta_calculado,
      s.id_almacen,s.stock_actual,s.costo_promedio,s.estado AS estado_stock
      FROM pro_producto p LEFT JOIN alm_producto_stock s ON s.id_producto=p.id
      WHERE p.estado=1 ORDER BY p.id,s.id_almacen`);
    console.log(JSON.stringify({costos: costs.rows}));
  } catch (error) {
    console.error('Diagnóstico no completado:', error.code || error.name);
    process.exitCode = 1;
  } finally { await client.end(); }
})();
