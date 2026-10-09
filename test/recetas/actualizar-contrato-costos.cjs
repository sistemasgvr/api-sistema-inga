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
    for (const file of [
      'productos-recetas-insumos/pro_costo_unitario_insumo.sql',
      'productos/pro_listar_productos.sql',
      'productos/pro_obtener_producto.sql',
      'productos-recetas-insumos/pro_obtener_receta.sql',
    ]) {
      await client.query(fs.readFileSync(path.join(__dirname, '../../database_sql/funciones/productos', file), 'utf8'));
    }
    const listado = (await client.query('SELECT pro_listar_productos() AS resultado')).rows[0].resultado;
    console.log(JSON.stringify({productos: listado.registros.filter(p => p.estado === 1).map(p => ({nombre:p.nombre,costo_unitario:p.costo_unitario,costo_receta:p.costo_receta_calculado}))}));
    const recetas = await client.query(`SELECT pro_obtener_receta(r.id) AS resultado
      FROM pro_receta r JOIN pro_producto p ON p.id=r.id_producto
      WHERE p.estado=1 AND r.estado=1 AND r.vigente`);
    for (const row of recetas.rows) {
      const r = row.resultado.registro;
      if (r.costo_total_calculado == null || r.insumos.some(i => i.costo_unitario_estimado == null || i.monto_subtotal == null)) throw new Error('Contrato incompleto');
      console.log(JSON.stringify({receta:r.nombre_producto,total:r.costo_total_calculado,insumos:r.insumos.map(i => ({nombre:i.nombre_insumo,costo:i.costo_unitario_estimado,subtotal:i.monto_subtotal}))}));
    }
    await client.query('COMMIT');
    console.log('Funciones actualizadas y verificadas.');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('Actualización no completada:', error.code || error.name);
    process.exitCode = 1;
  } finally { await client.end(); }
})();
