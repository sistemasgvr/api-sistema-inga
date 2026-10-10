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
(async()=>{try{await client.connect(); await client.query('BEGIN READ ONLY');
console.log(JSON.stringify((await client.query("SELECT id,codigo,id_sucursal,id_turno,estado_pedido,monto_total,monto_pagado FROM ven_pedido WHERE codigo='PED-18'")).rows));
console.log(JSON.stringify((await client.query('SELECT t.id,t.id_caja,t.estado,t.estado_turno,c.estado AS estado_caja,c.id_sucursal FROM caj_turno t JOIN caj_caja c ON c.id=t.id_caja ORDER BY t.id DESC LIMIT 8')).rows));
}catch(e){console.error(e.message);process.exitCode=1;}finally{await client.end();}})();