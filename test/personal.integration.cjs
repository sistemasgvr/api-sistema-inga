const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');
const root = path.resolve(__dirname, '..');
const name = `inga_personal_test_${Date.now()}`;
const config = { host:'127.0.0.1', port:55439, user:'pedidos_test', database:'postgres', connectionTimeoutMillis:5000 };
const admin = new Client(config);
let c;
let created = false;
let checks = 0;
const eq = (a,b) => { assert.deepEqual(a,b); checks++; };
function expand(file) {
  return fs.readFileSync(file,'utf8').replace(/^\\set.*$/gm,'').replace(/^\\ir (.+)$/gm,(_,relative)=>expand(path.resolve(path.dirname(file),relative.trim())));
}
(async()=>{
  await admin.connect();
  await admin.query(`CREATE DATABASE "${name}"`); created=true;
  c=new Client({...config,database:name}); await c.connect();
  await c.query(fs.readFileSync(path.join(root,'database_sql/database.sql'),'utf8')); await c.query('COMMIT');
  const install = expand(path.join(root,'database_sql/instalar_personal.sql'));
  await c.query(install); await c.query(install);
  const call = async (fn,args=[]) => (await c.query(`SELECT ${fn}(${args.map((_,i)=>'$'+(i+1)).join(',')}) AS r`,args)).rows[0].r;
  const crear = async (email=null) => (await call('pla_crear_trabajador',['Ana','Prueba',null,null,0,null,null,email,'999888777'])).registro;
  const t = await crear('ana@example.test');
  eq(t.email,'ana@example.test'); eq(t.id_usuario,null);
  eq((await call('auth_listar_trabajadores_disponibles',[t.id])).registros.map(x=>x.id),[t.id]);
  const u=(await call('auth_crear_usuario',['ana',t.id,'hash',null,'[]',null])).registro;
  eq(u.id_trabajador,t.id); eq(u.nombres,'Ana'); eq(u.password_hash,undefined);
  eq((await call('auth_listar_trabajadores_disponibles',[t.id])).registros,[]);
  await assert.rejects(()=>call('auth_crear_usuario',['otra',t.id,'hash']),/ya se encuentra registrado/);checks++;
  const noEmail=await crear();
  eq((await call('auth_listar_trabajadores_disponibles',[noEmail.id])).registros,[]);
  const inactive=await crear('inactiva@example.test');
  await call('pla_eliminar_trabajador',[inactive.id]);
  eq((await call('auth_listar_trabajadores_disponibles',[inactive.id])).registros,[]);
  eq((await call('auth_listar_trabajadores_disponibles',[-1])).registros,[]);
  await assert.rejects(()=>call('auth_crear_usuario',['sin-correo',noEmail.id,'hash']),/correo/);checks++;
  await assert.rejects(()=>crear('ANA@EXAMPLE.TEST'),/unique|duplicad/i);checks++;
  await call('pla_actualizar_trabajador',[t.id,'Andrea',null,null,null,null,null,null,'nuevo@example.test','123456']);
  const login=(await call('auth_obtener_usuario_por_login',['nuevo@example.test'])).registro;
  eq(login.nombres,'Andrea'); eq(login.telefono,'123456');
  eq((await call('auth_obtener_usuario_por_login',['ana@example.test'])).registro,null);
  await assert.rejects(()=>call('pla_actualizar_trabajador',[t.id,null,null,null,null,null,null,null,'',null]),/correo/);checks++;
  await call('auth_actualizar_usuario',[u.id,'andrea',null,null,'[]',null]);
  eq((await call('auth_obtener_usuario',[u.id])).registro.username,'andrea');
  await call('auth_crear_sesion',[u.id,'token']);
  eq((await call('auth_validar_sesion',['token'])).valida,true);
  await call('pla_eliminar_trabajador',[t.id]);
  eq((await call('auth_validar_sesion',['token'])).valida,false);
  eq((await call('auth_obtener_usuario_por_login',['nuevo@example.test'])).registro,null);
  await call('pla_activar_trabajador',[t.id]);
  eq((await call('auth_validar_sesion',['token'])).valida,false);
  eq((await call('auth_obtener_usuario_por_login',['nuevo@example.test'])).registro.id,u.id);
  eq((await call('auth_listar_usuarios',['Andrea'])).total,1);
  eq((await call('pla_obtener_trabajador',[t.id])).registro.id_usuario,u.id);
  const columns=(await c.query("SELECT column_name FROM information_schema.columns WHERE table_name='auth_usuario'")).rows.map(x=>x.column_name);
  eq(columns.includes('nombres'),false); eq(columns.includes('email'),false);
  // Simular estructura previa y comprobar la limpieza real dentro de una transacción.
  await c.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
  const oldSchema=fs.readFileSync(path.join(root,'database_sql/database.sql'),'utf8')
    .replace(/CREATE TABLE IF NOT EXISTS auth_usuario \([\s\S]*?\n\);/, `CREATE TABLE IF NOT EXISTS auth_usuario (
      id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      username VARCHAR(80) NOT NULL UNIQUE,
      email VARCHAR(255) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      pin_hash VARCHAR(255),
      nombres VARCHAR(100) NOT NULL,
      apellidos VARCHAR(100) NOT NULL,
      telefono VARCHAR(20),
      id_sucursal_default BIGINT REFERENCES gen_sucursal(id),
      es_super_admin BOOLEAN NOT NULL DEFAULT FALSE,
      estado SMALLINT NOT NULL DEFAULT 1,
      fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`)
    .replace(/^ALTER TABLE auth_usuario ADD CONSTRAINT fk_auth_usuario_trabajador[^\n]*\n/m,'')
    .replace(/CREATE OR REPLACE VIEW auth_usuario_datos AS[\s\S]*?;/,'');
  await c.query(oldSchema); await c.query('COMMIT');
  await c.query("INSERT INTO auth_usuario(username,email,password_hash,nombres,apellidos,es_super_admin) VALUES('admin','admin@example.test','hash','Admin','Prueba',true),('otro','otro@example.test','hash','Otro','Prueba',false)");
  await c.query("INSERT INTO pla_trabajador(nombres,apellidos) VALUES('Anterior','Prueba')");
  await c.query("INSERT INTO gen_empresa(ruc,razon_social) VALUES('20000000001','Pruebas')");
  await c.query("INSERT INTO gen_sucursal(id_empresa,codigo,nombre) VALUES(1,'TEST','Pruebas')");
  await c.query("INSERT INTO caj_caja(id_sucursal,codigo,nombre) VALUES(1,'TEST','Pruebas')");
  await c.query('INSERT INTO caj_turno(id_caja,id_cajero) VALUES(1,1)');
  const {apply}=require('../database_sql/utilidades/aplicar_personal.cjs');
  const simulation=await apply(c,{reset:true,dryRun:true});
  eq(simulation.resultado.usuarios,'1');
  eq((await c.query('SELECT count(*) FROM auth_usuario')).rows[0].count,'2');
  const migration=await apply(c,{reset:true});
  eq(migration.resultado.usuarios,'1'); eq(migration.resultado.trabajadores,'1'); eq(migration.resultado.sin_vinculo,'0');
  eq((await c.query('SELECT count(*) FROM caj_turno')).rows[0].count,'0');
  eq((await c.query('SELECT count(*) FROM gen_sucursal')).rows[0].count,'1');
  eq((await call('auth_obtener_usuario_por_login',['admin@example.test'])).registro.password_hash,'hash');
  await assert.rejects(()=>apply(c,{reset:true}),/ya está migrado/);checks++;
  console.log(`OK: ${checks} verificaciones de Personal; instalación repetida, vínculo único, datos compartidos, login y bajas.`);
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(async()=>{
  if(c) await c.end();
  if(created) await admin.query(`DROP DATABASE "${name}" WITH (FORCE)`);
  await admin.end();
});
