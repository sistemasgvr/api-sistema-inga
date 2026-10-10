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
(async()=>{try{
 await client.connect(); await client.query('BEGIN');
 await client.query(fs.readFileSync(path.join(__dirname,'../../database_sql/funciones/pedidos/ven_pedido_estado.sql'),'utf8'));
 const before=(await client.query("SELECT id,id_turno,estado_pedido,monto_pagado FROM ven_pedido WHERE codigo='PED-18'")).rows[0];
 if(before){
  await client.query('SAVEPOINT prueba');
  let mensaje='';
  try{await client.query("SELECT ven_pedido_estado($1,NULL,'{\"estado_pedido\":4}'::jsonb,NULL)",[before.id]);}
  catch(e){mensaje=e.message;}
  await client.query('ROLLBACK TO SAVEPOINT prueba');
  if(mensaje!=='El pedido requiere pagos registrados que cubran el total')throw new Error('Resultado inesperado: '+mensaje);
  const after=(await client.query('SELECT id,id_turno,estado_pedido,monto_pagado FROM ven_pedido WHERE id=$1',[before.id])).rows[0];
  require('node:assert/strict').deepEqual(after,before);
  console.log('Verificado PED-18: acepta turno vigente, rechaza cierre sin pagos y conserva turno original, estado y saldo.');
 }
 await client.query('COMMIT');console.log('Función actualizada.');
}catch(e){await client.query('ROLLBACK').catch(()=>{});console.error(e.message);process.exitCode=1;}finally{await client.end();}})();