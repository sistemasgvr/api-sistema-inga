/* Prueba real en una instancia LOCAL temporal con usuario pedidos_test.
 * No lee .env. Crea y elimina exclusivamente su propia base inga_pedidos_test_<timestamp>.
 * Iniciar previamente un clúster de pruebas en 127.0.0.1:55439 (ver docs/pedidos.md).
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Client, Pool } = require('pg');
const root = path.resolve(__dirname, '../..');
const config = { host: '127.0.0.1', port: 55439, user: 'pedidos_test', database: 'postgres', connectionTimeoutMillis: 5000 };
const name = `inga_inventario_test_${Date.now()}`;
const admin = new Client(config);
let pool;
let created = false;
let checks = 0;
const check = (actual, expected) => { assert.deepEqual(actual, expected); checks++; };
const rejects = async (fn, pattern) => { await assert.rejects(fn, pattern); checks++; };

async function main() {
  await admin.connect();
  assert.equal((await admin.query('SELECT current_user AS usuario')).rows[0].usuario, 'pedidos_test');
  await admin.query(`CREATE DATABASE "${name}"`);
  created = true;
  pool = new Pool({ ...config, database: name, max: 5 });
  const setup = await pool.connect();
  try {
    await setup.query(fs.readFileSync(path.join(root, 'database_sql/database.sql'), 'utf8'));
    // El esquema base contiene BEGIN; se confirma antes del instalador del módulo.
    await setup.query('COMMIT');
    const installer = fs.readFileSync(path.join(root, 'database_sql/instalar_inventario.sql'), 'utf8');
    const sql = installer.replace(/^\\set.*$/gm, '').replace(/^\\ir (.+)$/gm, (_, file) => fs.readFileSync(path.join(root, 'database_sql', file.trim()), 'utf8'));
    await setup.query(sql);
    await setup.query(sql); // La instalación se puede repetir.
  } finally { setup.release(); }
  const q = async (sql, params = []) => (await pool.query(sql, params)).rows;
  const insert = async (table, data) => {
    const columns = Object.keys(data);
    return (await q(`INSERT INTO ${table} (${columns.join(',')}) VALUES (${columns.map((_, i) => `$${i + 1}`).join(',')}) RETURNING id`, Object.values(data)))[0].id;
  };
  const empresa = await insert('gen_empresa', { ruc: '20000000001', razon_social: 'Pruebas' });
  const sucursal = await insert('gen_sucursal', { id_empresa: empresa, codigo: 'TEST', nombre: 'Pruebas' });
  const otraSucursal = await insert('gen_sucursal', { id_empresa: empresa, codigo: 'OTRA', nombre: 'Otra' });
  const usuarioTrabajador = await insert('pla_trabajador', { nombres: 'Admin', apellidos: 'Test', email: 'admin@test.local' });
  const usuario = await insert('auth_usuario', { username: 'admin_test', password_hash: 'test', id_trabajador: usuarioTrabajador });
  const mozoTrabajador = await insert('pla_trabajador', { nombres: 'Mozo', apellidos: 'Test', email: 'mozo@test.local' });
  const mozo = await insert('auth_usuario', { username: 'mozo_test', password_hash: 'test', id_trabajador: mozoTrabajador });
  const rol = (await q("SELECT id FROM auth_rol WHERE codigo = 'ADMIN'"))[0].id;
  await insert('auth_usuario_rol', { id_usuario: usuario, id_rol: rol });
  const caja = await insert('caj_caja', { id_sucursal: sucursal, codigo: 'CAJA', nombre: 'Caja' });
  const turno = await insert('caj_turno', { id_caja: caja, id_cajero: usuario });
  const salon = await insert('ven_salon', { id_sucursal: sucursal, codigo: 'SALON', nombre: 'Salón' });
  const mesa = await insert('ven_mesa', { id_salon: salon, codigo: 'M1' });
  const almacen = await insert('gen_almacen', { id_sucursal: sucursal, codigo: 'COC', nombre: 'Cocina', tipo_almacen: 2 });
  const cocina = await insert('gen_estacion', { id_sucursal: sucursal, codigo: 'COC', nombre: 'Cocina', tipo_estacion: 1 });
  const barra = await insert('gen_estacion', { id_sucursal: sucursal, codigo: 'BAR', nombre: 'Barra', tipo_estacion: 2 });
  const categoria = await insert('pro_categoria', { codigo: 'TEST', nombre: 'Pruebas' });
  const subcategoria = await insert('pro_subcategoria', { id_categoria: categoria, codigo: 'TEST', nombre: 'Pruebas' });
  const kg = (await q("SELECT id FROM pro_unidad_medida WHERE codigo = 'KG'"))[0].id;
  const gramos = (await q("SELECT id FROM pro_unidad_medida WHERE codigo = 'G'"))[0].id;
  const product = (codigo, data = {}) => insert('pro_producto', { id_subcategoria: subcategoria, id_unidad_medida: kg, id_estacion: cocina, id_almacen_stock: almacen, codigo_interno: codigo, nombre: codigo, tipo_producto: 2, controla_stock: true, precio_venta: 11.80, ...data });
  const insumo = await product('INSUMO');
  const bebida = await product('BEBIDA', { tipo_producto: 6, id_estacion: barra, afecto_igv: false, precio_venta: 10 });
  const plato = await product('PLATO', { tipo_producto: 3, controla_stock: true });
  await insert('alm_producto_stock', { id_usuario_creacion: usuario, id_almacen: almacen, id_producto: insumo, stock_actual: 10, costo_promedio: 5 });
  await insert('alm_producto_stock', { id_usuario_creacion: usuario, id_almacen: almacen, id_producto: bebida, stock_actual: 10, costo_promedio: 3 });
  const receta = await insert('pro_receta', { id_producto: plato, rendimiento_porciones: 2 });
  const ri = await insert('pro_receta_insumo', { id_receta: receta, id_producto_insumo: insumo, cantidad: 200, id_unidad_medida: gramos, porcentaje_merma: 10 });
  const adicional = await insert('pro_adicional', { id_producto: plato, nombre: 'Extra', precio_adicional: 1.18, id_producto_insumo: insumo, cantidad_insumo: 50, id_unidad_medida: gramos });
  const call = async (accion, id = null, item = null, datos = {}, actor = usuario) => (await q(`SELECT ven_pedido_${accion}($1,$2,$3::jsonb,$4) AS result`, [id, item, JSON.stringify(datos), actor]))[0].result.registro;
  const openData = { tipo_pedido: 1, id_mesa: Number(mesa), id_mozo: Number(mozo), id_turno: Number(turno), tasa_igv: 18 };
  const abrir = () => call('abrir', null, null, openData);
  const llevar = () => call('abrir', null, null, { ...openData, tipo_pedido: 2, id_mesa: null, id_sucursal: Number(sucursal) });
  const anulacion = { id_usuario_autoriza: Number(usuario), motivo: 'Prueba de reverso' };
  const stock = async id => Number((await q('SELECT stock_actual FROM alm_producto_stock WHERE id_producto = $1 AND id_almacen=$2', [id,almacen]))[0].stock_actual);
  const estadoMesa = async () => (await q('SELECT estado_mesa FROM ven_mesa WHERE id = $1', [mesa]))[0].estado_mesa;
  const obtener = async id => (await q('SELECT ven_obtener_pedido($1) AS r', [id]))[0].r.registro;
  const agregar = (id, producto, cantidad = 1, extras = {}) => call('agregar_item', id, null, { id_producto: Number(producto), cantidad, ...extras });


  // Simula una BD anterior con kardex real, sin aplicar otra vez el saldo al migrar.
  await q('DROP VIEW vw_alm_kardex; DROP TABLE alm_movimiento_detalle; DROP TABLE alm_movimiento');
  await q(fs.readFileSync(path.join(__dirname,'fixtures/inventario-anterior.sql'),'utf8'));
  await insert('alm_kardex',{id_producto:insumo,id_almacen:almacen,id_unidad_medida:kg,tipo_movimiento:1,signo:1,
    cantidad:10,stock_anterior:0,stock_nuevo:10,costo_unitario:5,id_usuario_creacion:usuario});
  const installerText=fs.readFileSync(path.join(root,'database_sql/instalar_inventario.sql'),'utf8');
  const migrationSql=installerText.replace(/^\\set.*$/gm,'').replace(/^\\ir (.+)$/gm,(_,file)=>fs.readFileSync(path.join(root,'database_sql',file.trim()),'utf8'));
  await q(migrationSql);
  check(await stock(insumo),10);
  check(Number((await q('SELECT count(*) n FROM historial_almacen.alm_kardex'))[0].n),1);
  check(Number((await q("SELECT count(*) n FROM alm_movimiento WHERE codigo LIKE 'LEGACY-%'"))[0].n),1);
  await q(migrationSql);
  check(Number((await q("SELECT count(*) n FROM alm_movimiento WHERE codigo LIKE 'LEGACY-%'"))[0].n),1);

  const preparar = async (codigo, cantidad, item) => (await q('SELECT prod_preparar($1::jsonb,$2) AS r',
    [JSON.stringify({codigo,id_receta:Number(receta),id_almacen_destino:Number(almacen),cantidad,id_pedido_detalle:item ? Number(item) : undefined}),usuario]))[0].r.registro;
  const reserva = async id => Number((await q('SELECT stock_reservado FROM alm_producto_stock WHERE id_producto=$1',[id]))[0]?.stock_reservado ?? 0);
  const totalMov = async () => Number((await q('SELECT count(*) AS n FROM alm_movimiento'))[0].n);
  await preparar('LOTE-1',2);
  check(await stock(insumo),9.78);
  check(await stock(plato),2);
  const antes=await totalMov();
  await preparar('LOTE-1',2);
  check(await totalMov(),antes);
  await rejects(()=>preparar('LOTE-1',3),/otros datos/);

  let pedido=await llevar();
  pedido=await agregar(pedido.id,plato,3);
  const item=pedido.items[0].id;
  pedido=await call('comandar',pedido.id);
  check(await stock(insumo),9.78);
  check(await reserva(plato),2);
  check(pedido.items[0].cantidad_reservada,2);
  await rejects(()=>call('entregar',pedido.id,item,{cantidad_entregada:3}),/Faltan/);
  check(await stock(plato),2);
  await preparar('POR-PEDIDO',1,item);
  check(await stock(insumo),9.67);
  check(await reserva(plato),3);
  pedido=await call('entregar',pedido.id,item,{cantidad_entregada:2});
  check(await stock(plato),1);
  check(await reserva(plato),1);
  const entregas=await totalMov();
  await call('entregar',pedido.id,item,{cantidad_entregada:2});
  check(await totalMov(),entregas);
  pedido=await call('anular_item',pedido.id,item,{...anulacion,cantidad_cancelada:1,destino_preparado:'DISPONIBLE'});
  check(await reserva(plato),0);
  check(await stock(plato),1);
  check(await stock(insumo),9.67);
  check(pedido.items[0].cantidad_cancelada,1);
  check(pedido.monto_total,23.6);
  await call('anular_item',pedido.id,item,{...anulacion,cantidad_cancelada:1,destino_preparado:'DISPONIBLE'});
  check(await stock(plato),1);
  await rejects(()=>call('anular',pedido.id,null,anulacion),/entregados/);

  // Dos pedidos compiten por una sola porción: únicamente uno la reserva.
  let a=await llevar(),b=await llevar();
  a=await agregar(a.id,plato); b=await agregar(b.id,plato);
  await Promise.all([call('comandar',a.id),call('comandar',b.id)]);
  check(await reserva(plato),1);
  const aa=await obtener(a.id),bb=await obtener(b.id);
  const ganador=aa.items[0].cantidad_reservada ? aa : bb;
  await rejects(()=>call('anular',ganador.id,null,anulacion),/destino_preparado/);
  await call('anular',ganador.id,null,{...anulacion,destino_preparado:'MERMA'});
  check(await stock(plato),0); check(await reserva(plato),0); check(await stock(insumo),9.67);
  const postMerma=await totalMov();
  await call('anular',ganador.id,null,{...anulacion,destino_preparado:'MERMA'});
  check(await totalMov(),postMerma);

  // Gaseosa: reserva y una sola línea de venta, sin receta.
  let gas=await llevar(); gas=await agregar(gas.id,bebida); gas=await call('comandar',gas.id);
  check(await stock(bebida),10); check(await reserva(bebida),1);
  await call('entregar',gas.id,gas.items[0].id,{cantidad_entregada:1});
  check(await stock(bebida),9);
  check(Number((await q("SELECT count(*) n FROM vw_alm_kardex WHERE documento_tipo='PEDIDO_DETALLE' AND documento_id=$1",[gas.items[0].id]))[0].n),1);

  // Producción sin existencias: no deja cabecera ni movimientos a medias.
  const antesFallo=await totalMov();
  await rejects(()=>preparar('SIN-STOCK',999),/insuficiente/);
  check(await totalMov(),antesFallo);
  check(Number((await q("SELECT count(*) n FROM prod_orden WHERE codigo='SIN-STOCK'"))[0].n),0);
  check(Number((await q('SELECT count(*) n FROM alm_movimiento_detalle WHERE id_usuario_creacion IS NULL OR fecha_creacion IS NULL'))[0].n),0);
  const confirmado=(await q('SELECT id FROM alm_movimiento WHERE estado=2 LIMIT 1'))[0].id;
  await rejects(()=>q('UPDATE alm_movimiento SET observacion=$1 WHERE id=$2',['alterar',confirmado]),/inmutable/);
  await rejects(()=>q('UPDATE alm_movimiento_detalle SET cantidad=cantidad+1 WHERE id_movimiento=$1',[confirmado]),/inmutable/);
  const beforeConfirm=await totalMov();
  await q('SELECT alm_confirmar($1,$2)',[confirmado,usuario]);
  check(await totalMov(),beforeConfirm);

  // Movimientos generales: confirmar una compra, traslado y validación del catálogo.
  const opcion=async(lista,codigo)=>Number((await q('SELECT o.id FROM gen_lista_opcion o JOIN gen_lista l ON l.id=o.id_lista WHERE l.codigo=$1 AND o.codigo=$2',[lista,codigo]))[0].id);
  const entrada=await opcion('ALM_TIPO_MOVIMIENTO','ENTRADA'),salidaTipo=await opcion('ALM_TIPO_MOVIMIENTO','SALIDA');
  const compra=await opcion('ALM_MOTIVO_MOVIMIENTO','COMPRA');
  const linea={id_producto:Number(bebida),id_almacen:Number(almacen),id_unidad_medida:Number(kg),cantidad:2,signo:1,costo_unitario:4};
  const registrar=async(datos)=>(await q('SELECT alm_registrar($1::jsonb,$2) r',[JSON.stringify(datos),usuario]))[0].r.registro;
  const borrador=await registrar({codigo:'COMPRA-TEST',id_tipo_movimiento:entrada,id_motivo_movimiento:compra,detalles:[linea]});
  check(await stock(bebida),9);
  await q('SELECT alm_confirmar($1,$2)',[borrador.id,usuario]);
  check(await stock(bebida),11);
  await rejects(()=>registrar({codigo:'TIPO-INVALIDO',id_tipo_movimiento:salidaTipo,id_motivo_movimiento:compra,detalles:[{...linea,signo:-1}],confirmar:true}),/incompatibles/);
  const destino=await insert('gen_almacen',{id_sucursal:sucursal,codigo:'DEST',nombre:'Destino',tipo_almacen:2});
  await registrar({codigo:'TRASLADO-TEST',id_tipo_movimiento:await opcion('ALM_TIPO_MOVIMIENTO','TRASLADO'),
    id_motivo_movimiento:await opcion('ALM_MOTIVO_MOVIMIENTO','ABASTECIMIENTO_INTERNO'),confirmar:true,
    detalles:[{...linea,signo:-1},{...linea,id_almacen:Number(destino)}]});
  check(await stock(bebida),9);
  check(Number((await q('SELECT stock_actual FROM alm_producto_stock WHERE id_producto=$1 AND id_almacen=$2',[bebida,destino]))[0].stock_actual),2);
  // La entrada del traslado toma el costo real de salida, no el costo enviado por el cliente.
  const costos=await q("SELECT d.costo_unitario FROM alm_movimiento_detalle d JOIN alm_movimiento m ON m.id=d.id_movimiento WHERE m.codigo='TRASLADO-TEST'");
  check(costos[0].costo_unitario,costos[1].costo_unitario);
  await rejects(async()=>registrar({codigo:'TRASLADO-INCOMPLETO',id_tipo_movimiento:await opcion('ALM_TIPO_MOVIMIENTO','TRASLADO'),
    id_motivo_movimiento:await opcion('ALM_MOTIVO_MOVIMIENTO','ABASTECIMIENTO_INTERNO'),confirmar:true,detalles:[{...linea,signo:-1}]}),/Traslado requiere/);
  const cancelable=await registrar({codigo:'BORRADOR-CANCELAR',id_tipo_movimiento:entrada,id_motivo_movimiento:compra,detalles:[linea]});
  await q('SELECT alm_cancelar($1,$2)',[cancelable.id,usuario]);
  await rejects(()=>q('SELECT alm_confirmar($1,$2)',[cancelable.id,usuario]),/cancelado/);
  check(await stock(bebida),9);

  let especial=await llevar();
  especial=await agregar(especial.id,plato,1,{adicionales:[{id_adicional:Number(adicional)}]});
  especial=await call('comandar',especial.id);
  check(especial.items[0].cantidad_reservada,0);
  await preparar('ESPECIAL',1,especial.items[0].id);
  check(await stock(insumo),9.51);
  await rejects(()=>call('anular',especial.id,null,{...anulacion,destino_preparado:'DISPONIBLE'}),/personalizada/);
  await call('entregar',especial.id,especial.items[0].id,{cantidad_entregada:1});
  check(await stock(insumo),9.51); // No descuenta el adicional por segunda vez.

  await rejects(()=>call('anular',gas.id,null,{id_usuario_autoriza:Number(mozo),motivo:'Sin permiso'},mozo),/autoriza|permiso|rol/i);
  await rejects(()=>call('entregar',gas.id,especial.items[0].id,{cantidad_entregada:1}),/no encontrado/);
  await call('estado',gas.id,null,{estado_pedido:3});
  await rejects(()=>call('estado',gas.id,null,{estado_pedido:4}),/pagos/);
  // Las lecturas del model usan funciones individuales y conservan sus respuestas.
  const stockLeido=(await q('SELECT alm_listar_stock($1,$2,50,0) r',[bebida,almacen]))[0].r;
  check(stockLeido.registros.length,1);
  check(Number(stockLeido.registros[0].stock_actual),9);
  const kardexLeido=(await q('SELECT alm_listar_kardex($1,$2,1,0) r',[bebida,almacen]))[0].r;
  check(kardexLeido.registros.length,1);
  const movLeido=(await q('SELECT alm_obtener_movimiento($1) r',[confirmado]))[0].r;
  check(Number(movLeido.registro.id),Number(confirmado));
  check(movLeido.registro.detalles.length>0,true);
  check((await q('SELECT alm_obtener_movimiento(9223372036854775807) r'))[0].r.registro,null);
  console.log('Inventario: '+checks+' comprobaciones correctas');
}
main().catch(e=>{ console.error(e);process.exitCode=1; }).finally(async()=>{
  if(pool) await pool.end();
  if(created) await admin.query('DROP DATABASE "'+name+'"');
  await admin.end();
});
