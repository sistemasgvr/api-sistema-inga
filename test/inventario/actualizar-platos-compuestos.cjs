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
// Platos hechos de otros platos (docs/plan-platos-compuestos.md). El orden respeta las dependencias.
const archivos = [
  'migraciones/14_reserva_insumo_origen.sql',
  'funciones/productos/productos-recetas-insumos/pro_receta_vigente.sql',
  'funciones/productos/productos-recetas-insumos/pro_explotar_receta.sql',
  'funciones/pedidos/ven_consumos_item.sql',
  'funciones/pedidos/ven_liberar_insumos.sql',
  'funciones/inventario/alm_agrupar_detalles.sql',
  'funciones/produccion/prod_cubrir_subplato.sql',
  'funciones/pedidos/ven_reservar_insumos_pedido.sql',
  'funciones/pedidos/ven_cancelar_stock_item.sql',
  'funciones/produccion/prod_preparar.sql',
  'funciones/produccion/prod_disponibilidad.sql',
  'funciones/produccion/prod_listar_productos.sql',
  'funciones/pedidos/ven_obtener_pedido.sql',
  'funciones/pedidos/ven_listar_cocina.sql',
];
(async () => {
  try {
    await client.connect();
    await client.query('BEGIN');
    for (const file of archivos) {
      await client.query(fs.readFileSync(path.join(__dirname, '../../database_sql', file), 'utf8'));
    }
    await client.query('COMMIT');
    console.log('Platos compuestos instalados: las reservas existentes se conservan y siguen funcionando.');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('No se pudo actualizar:', error.code || error.name, error.message);
    process.exitCode = 1;
  } finally { await client.end(); }
})();
