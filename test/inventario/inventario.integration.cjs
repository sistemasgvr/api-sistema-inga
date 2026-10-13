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
    // Datos exclusivos de esta base temporal; no se migran datos de usuario.
    await setup.query(`INSERT INTO pro_tipo_producto(id,nombre,permite_venta,requiere_receta,requiere_estacion,permite_stock_inicial) VALUES
      (1,'Crudo',false,false,false,true),(2,'Procesado',false,true,false,true),
      (3,'Carta',true,true,true,false),(4,'Menú',true,true,true,false),(5,'Trago',true,true,true,false),
      (6,'Bebida',true,false,true,true),(7,'Adicional',true,false,false,true);
      SELECT setval(pg_get_serial_sequence('pro_tipo_producto','id'),7);`);
    const tiposInstaller = fs.readFileSync(path.join(root, 'database_sql/instalar_tipos_producto.sql'), 'utf8');
    const tiposSql = tiposInstaller.replace(/^\\set.*$/gm, '').replace(/^\\ir (.+)$/gm, (_, file) => fs.readFileSync(path.join(root, 'database_sql', file.trim()), 'utf8'));
    await setup.query(tiposSql);
    await setup.query(tiposSql);
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
  const permisoAnular = (await q("SELECT id FROM auth_permiso WHERE codigo = 'pedidos.anular'"))[0].id;
  const autorizar = (actor, autoriza = actor, motivo = 'Prueba de permisos') =>
    q('SELECT ven_autorizar_anulacion($1,$2,$3)', [actor, autoriza, motivo]);
  // El nombre ADMIN no autoriza sin la bandera; un rol personalizado sí puede hacerlo.
  await q('DELETE FROM auth_rol_permiso WHERE id_rol=$1 AND id_permiso=$2', [rol, permisoAnular]);
  await rejects(() => autorizar(usuario), /pedidos.anular/);
  const asignacion = await insert('auth_rol_permiso', { id_rol: rol, id_permiso: permisoAnular });
  await autorizar(usuario);
  const rolPersonalizado = await insert('auth_rol', { codigo: 'SUPERVISOR_TEST', nombre: 'Supervisor de prueba' });
  const membresia = await insert('auth_usuario_rol', { id_usuario: mozo, id_rol: rolPersonalizado });
  await insert('auth_rol_permiso', { id_rol: rolPersonalizado, id_permiso: permisoAnular });
  await autorizar(mozo);
  await rejects(() => autorizar(mozo, usuario), /usuario autenticado/);
  for (const [table, id] of [['auth_usuario_rol', membresia], ['auth_rol', rolPersonalizado], ['auth_permiso', permisoAnular]]) {
    await q(`UPDATE ${table} SET estado=0 WHERE id=$1`, [id]);
    await rejects(() => autorizar(mozo), /pedidos.anular/);
    await q(`UPDATE ${table} SET estado=1 WHERE id=$1`, [id]);
  }
  await q('UPDATE auth_rol_permiso SET estado=0 WHERE id=$1', [asignacion]);
  await rejects(() => autorizar(usuario), /pedidos.anular/);
  await q('UPDATE auth_rol_permiso SET estado=1 WHERE id=$1', [asignacion]);
  await q('DELETE FROM auth_usuario_rol WHERE id=$1', [membresia]);
  await q('UPDATE auth_usuario SET es_super_admin=true WHERE id=$1', [mozo]);
  await autorizar(mozo); // Superadministrador sin roles ni permisos asignados.
  await rejects(() => autorizar(mozo, usuario), /usuario autenticado/);
  await rejects(() => autorizar(mozo, mozo, '  '), /motivo/);
  await q('UPDATE auth_usuario SET estado=0 WHERE id=$1', [mozo]);
  await rejects(() => autorizar(mozo), /pedidos.anular/);
  await q('UPDATE auth_usuario SET estado=1,es_super_admin=false WHERE id=$1', [mozo]);
  await rejects(() => autorizar(mozo), /pedidos.anular/);
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
  const tipoNuevo = (await q("SELECT pro_crear_tipo_producto('Tipo nuevo',true,true,true,false,$1) AS r", [usuario]))[0].r.registro;
  check(tipoNuevo.id > 7, true);
  const duplicado = (await q("SELECT pro_crear_tipo_producto('  TIPO NUEVO  ',false,false,false,true,$1) AS r", [usuario]))[0].r;
  check(!!duplicado.error, true);
  const tipos = (await q('SELECT pro_listar_tipos_producto() AS r'))[0].r;
  check(tipos.find(t => t.id === tipoNuevo.id).requiere_receta, true);
  const nuevo = {id_subcategoria:subcategoria,id_unidad_medida:kg,nombre:'Dinámico',
    tipo_producto:tipoNuevo.id,controla_stock:true,id_almacen_stock:almacen,precio_venta:20,disponible_venta:true};
  const crear = async data => (await q('SELECT pro_crear_producto_stock($1::jsonb,$2) AS r',[JSON.stringify(data),usuario]))[0].r;
  check(!!(await crear(nuevo)).error, true); // Estación requerida para un ID nuevo.
  await rejects(() => crear({...nuevo,id_estacion:cocina,stock_inicial:2}), /no permite stock/);
  const dinamico = (await crear({...nuevo,id_estacion:cocina})).registro;
  check(dinamico.nombre_tipo_producto, 'Tipo nuevo');
  check(dinamico.requiere_receta, true);
  const modificado = (await q(`SELECT pro_actualizar_producto(p_id => $1::bigint, p_tipo_producto => 1::smallint) AS r`,[dinamico.id]))[0].r.registro;
  check(modificado.id_estacion, null);
  check(modificado.disponible_venta, false);
  check(Number(modificado.precio_venta), 0);
  check(!!(await q('SELECT pro_toggle_disponibilidad_producto($1) AS r',[dinamico.id]))[0].r.error, true);
  const sinStock = (await q('SELECT pro_actualizar_producto(p_id => $1::bigint,p_controla_stock => false) AS r',[dinamico.id]))[0].r.registro;
  check(sinStock.id_almacen_stock, null);
  check(!!(await crear({...nuevo,tipo_producto:30000})).error, true);
  const product = (codigo, data = {}) => insert('pro_producto', { id_subcategoria: subcategoria, id_unidad_medida: kg, id_estacion: cocina, id_almacen_stock: almacen, nombre: codigo, tipo_producto: 2, controla_stock: true, precio_venta: 11.80, ...data });
  const insumo = await product('INSUMO');
  const bebida = await product('BEBIDA', { tipo_producto: 6, id_estacion: barra, afecto_igv: false, precio_venta: 10 });
  const plato = await product('PLATO', { tipo_producto: tipoNuevo.id, controla_stock: true });
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
  await q('DROP VIEW vw_alm_kardex; DROP TABLE alm_movimiento_detalle; DROP TABLE alm_movimiento CASCADE');
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
  // Consultas de formularios: disponibilidad real, filtrado y paginación en SQL.
  const disponible=(await q('SELECT prod_disponibilidad($1,$2,2) r',[receta,almacen]))[0].r.registro;
  check(disponible.ingredientes.length,1);
  check(Number(disponible.ingredientes[0].requerido),0.22);
  // 9.51 kg menos 0.11 apartados para el pedido que perdió la porción: (9.51-0.11)/0.11 = 85.
  check(Number(disponible.posibles_preparar),85);
  check(Number(disponible.ingredientes[0].faltante),0);
  const personalizado=(await q('SELECT prod_disponibilidad($1,$2,1,$3) r',[receta,almacen,especial.items[0].id]))[0].r.registro;
  check(Number(personalizado.ingredientes[0].requerido),0.16);
  const preparables=(await q('SELECT prod_listar_productos($1) r',[sucursal]))[0].r;
  check(preparables.some(p=>Number(p.id)===Number(plato)),true);
  check((await q('SELECT prod_listar_productos($1) r',[otraSucursal]))[0].r.length,0);
  const paginaStock=(await q("SELECT alm_buscar_stock(NULL,NULL,1,0,'BEBIDA','todos') r"))[0].r;
  check(paginaStock.total,2);
  check(paginaStock.registros.length,1);
  check(Number(paginaStock.registros[0].id_unidad_medida),Number(kg));
  check((await q("SELECT alm_buscar_stock(NULL,NULL,1,1,'BEBIDA','todos') r"))[0].r.registros.length,1);
  const listaMotivos=(await q("SELECT id FROM gen_lista WHERE codigo='ALM_MOTIVO_MOVIMIENTO'"))[0].id;
  const motivos=(await q('SELECT gen_filtrar_opciones_lista($1,4) r',[listaMotivos]))[0].r.registro.opciones;
  check(motivos.length>0,true);
  check(motivos.every(m=>m.valor_entero===4),true);

  // Alta de producto + saldo inicial: una única operación con auditoría y rollback.
  const alta={id_subcategoria:Number(subcategoria),id_unidad_medida:Number(kg),id_estacion:Number(barra),id_almacen_stock:Number(almacen),
    nombre:'Nueva gaseosa',tipo_producto:6,controla_stock:true,stock_inicial:4,stock_minimo:2,costo_inicial:3};
  const crearProducto=async data=>(await q('SELECT pro_crear_producto_stock($1::jsonb,$2) r',[JSON.stringify(data),usuario]))[0].r;
  const creado=(await crearProducto(alta)).registro;
  check(!!creado,true);
  check(await stock(creado.id),4);
  const stockInicial=(await q('SELECT * FROM alm_producto_stock WHERE id_producto=$1',[creado.id]))[0];
  check(Number(stockInicial.stock_minimo),2);
  check(Number(stockInicial.costo_promedio),3);
  check(Number(stockInicial.id_usuario_creacion),Number(usuario));
  check(Number((await q("SELECT count(*) n FROM vw_alm_kardex WHERE documento_tipo='PRODUCTO' AND documento_id=$1",[creado.id]))[0].n),1);
  await rejects(()=>crearProducto({...alta,tipo_producto:3}),/no permite stock/);
  const saldoInicial=await opcion('ALM_MOTIVO_MOVIMIENTO','SALDO_INICIAL');
  await q('UPDATE gen_lista_opcion SET estado=0 WHERE id=$1',[saldoInicial]);
  await rejects(()=>crearProducto({...alta,nombre:'ALTA-ROLLBACK'}),/catálogo|Catálogo|motivo|Motivo/);
  check(Number((await q("SELECT count(*) n FROM pro_producto WHERE nombre='ALTA-ROLLBACK'"))[0].n),0);
  await q('UPDATE gen_lista_opcion SET estado=1 WHERE id=$1',[saldoInicial]);

  // Cocina: iniciar no descuenta; confirmar preparación sí, entrega no repite ingredientes.
  let ronda=await llevar();ronda=await agregar(ronda.id,plato);ronda=await call('comandar',ronda.id);
  const primera=ronda.items[0].id;
  const antesCocina=await stock(insumo),movsCocina=await totalMov();
  ronda=await call('preparacion',ronda.id,primera,{estado_preparacion:3});
  check(ronda.items[0].estado_preparacion,3);
  await call('preparacion',ronda.id,primera,{estado_preparacion:3});
  check(await totalMov(),movsCocina);
  check(await stock(insumo),antesCocina);
  await rejects(()=>call('preparacion',ronda.id,primera,{estado_preparacion:4}),/producción/);
  const cola=(await q('SELECT ven_listar_cocina($1,$2,false,200,0) r',[sucursal,cocina]))[0].r;
  check(cola.registros.some(d=>Number(d.id)===Number(primera)),true);
  check((await q('SELECT ven_listar_cocina($1,NULL,false,200,0) r',[otraSucursal]))[0].r.total,0);
  await preparar('RONDA-COCINA',1,primera);
  check(await stock(insumo),Number((antesCocina-0.11).toFixed(4)));
  ronda=await call('entregar',ronda.id,primera,{cantidad_entregada:1});
  check(ronda.items[0].estado_preparacion,5);
  const despuesEntrega=await stock(insumo),movsEntrega=await totalMov();
  await call('entregar',ronda.id,primera,{cantidad_entregada:1});
  check(await totalMov(),movsEntrega);
  ronda=await agregar(ronda.id,plato);ronda=await call('comandar',ronda.id);
  check(ronda.items.find(i=>Number(i.id)===Number(primera)).estado_preparacion,5);
  check(ronda.items.filter(i=>i.estado_preparacion===2).length,1);
  check(await stock(insumo),despuesEntrega);
  const pendientes=(await q('SELECT ven_listar_cocina($1,NULL,false,200,0) r',[sucursal]))[0].r;
  check(pendientes.registros.some(d=>Number(d.id)===Number(primera)),false);
  const historial=(await q('SELECT ven_listar_cocina($1,NULL,true,200,0) r',[sucursal]))[0].r;
  check(historial.registros.some(d=>Number(d.id)===Number(primera)),true);

  // Reserva de insumos al comandar (0.11 kg de insumo por plato).
  const r4=x=>Number(Number(x).toFixed(4));
  const reservaInsumo=async()=>r4(await reserva(insumo));
  const reservaLinea=async item=>r4((await q('SELECT COALESCE(sum(cantidad),0) n FROM ven_pedido_reserva_insumo WHERE id_pedido_detalle=$1',[item]))[0].n);

  // Comandar y anular sin preparar devuelve exactamente lo apartado.
  const baseInsumo=await reservaInsumo(),basePlato=await reserva(plato);
  let suelta=await llevar();suelta=await agregar(suelta.id,plato,2);suelta=await call('comandar',suelta.id);
  check(await reservaInsumo(),r4(baseInsumo+0.22-0.11*Number(suelta.items[0].cantidad_reservada)));
  await call('anular',suelta.id,null,{...anulacion,destino_preparado:'DISPONIBLE'});
  check(await reservaInsumo(),baseInsumo);check(await reserva(plato),basePlato);

  // 21 platos: toma los 5 preparados por adelantado y aparta ingredientes para los 16 restantes.
  await preparar('LOTE-21',5);
  const insumo21=await stock(insumo),reserva21=await reservaInsumo(),plato21=await reserva(plato);
  let grande=await llevar();grande=await agregar(grande.id,plato,21);grande=await call('comandar',grande.id);
  const lg=grande.items[0].id;
  check(grande.items[0].cantidad_reservada,5);
  check(await reserva(plato),plato21+5);
  check(await reservaInsumo(),r4(reserva21+1.76));
  check(await stock(insumo),insumo21); // Apartar no descuenta existencias.
  // Lo apartado por la propia línea cuenta como disponible para prepararla.
  const dispLinea=(await q('SELECT prod_disponibilidad($1,$2,16,$3) r',[receta,almacen,lg]))[0].r.registro;
  check(Number(dispLinea.ingredientes[0].faltante),0);
  await preparar('GRANDE-10',10,lg);
  check(await stock(insumo),r4(insumo21-1.1));
  check(await reservaLinea(lg),0.66);
  grande=await obtener(grande.id);
  check(grande.items[0].estado_preparacion,3);
  // En preparación: cancelar unidades sin preparar exige elegir el destino de sus ingredientes.
  await rejects(()=>call('anular_item',grande.id,lg,{...anulacion,cantidad_cancelada:3}),/destino_insumos/);
  await call('anular_item',grande.id,lg,{...anulacion,cantidad_cancelada:3,destino_insumos:'LIBERAR'});
  check(await reservaLinea(lg),0.33);check(await stock(insumo),r4(insumo21-1.1));
  await call('anular_item',grande.id,lg,{...anulacion,cantidad_cancelada:5,destino_insumos:'MERMA'});
  check(await reservaLinea(lg),0.11);check(await stock(insumo),r4(insumo21-1.32));
  check(Number((await q("SELECT count(*) n FROM vw_alm_kardex WHERE motivo='MERMA' AND documento_id=$1 AND id_producto=$2",[lg,insumo]))[0].n),1);
  // Cancelar 2 más: primero la última unidad sin preparar y luego un plato preparado.
  await rejects(()=>call('anular_item',grande.id,lg,{...anulacion,cantidad_cancelada:7,destino_insumos:'LIBERAR'}),/destino_preparado/);
  grande=await call('anular_item',grande.id,lg,{...anulacion,cantidad_cancelada:7,destino_insumos:'LIBERAR',destino_preparado:'DISPONIBLE'});
  check(await reservaLinea(lg),0);check(grande.items[0].cantidad_reservada,14);
  check(await reserva(plato),plato21+14);

  // Sin insumos suficientes: se rechaza todo, sin comanda ni reservas, con faltantes para el aviso.
  const comandas=async()=>Number((await q('SELECT count(*) n FROM ven_comanda'))[0].n);
  const antesFalta={comandas:await comandas(),insumo:await reservaInsumo(),plato:await reserva(plato)};
  let falta=await llevar();falta=await agregar(falta.id,plato,1000);
  const errorFalta=await call('comandar',falta.id).then(()=>null,e=>e);
  check(errorFalta?.code,'IN001');
  check(/No hay stock suficiente para comandar: INSUMO \(falta [\d.]+ \S+\)/.test(errorFalta.message),true);
  const faltantes=JSON.parse(errorFalta.detail);
  check([faltantes[0].producto,faltantes[0].platos,faltantes[0].estaciones],['INSUMO',['PLATO'],[Number(cocina)]]);
  check(await comandas(),antesFalta.comandas);check(await reservaInsumo(),antesFalta.insumo);check(await reserva(plato),antesFalta.plato);
  check((await obtener(falta.id)).estado_pedido,1);
  const avisar=async()=>(await q('SELECT ven_registrar_aviso_cocina($1,$2,$3::jsonb,$4) r',[falta.id,errorFalta.message,errorFalta.detail,mozo]))[0].r.registro;
  const aviso=await avisar();await avisar(); // Reintentar la comanda no duplica el aviso pendiente.
  // Solo avisos de faltantes; las cancelaciones también generan avisos sin faltantes.
  const avisos=async estacion=>(await q('SELECT ven_listar_avisos_cocina($1,$2) r',[sucursal,estacion]))[0].r.filter(a=>a.faltantes.length>0);
  check((await avisos(cocina)).map(a=>Number(a.id)),[Number(aviso.id)]);
  check((await avisos(barra)).length,0);
  await q('SELECT ven_atender_aviso_cocina($1,$2)',[aviso.id,usuario]);
  check((await avisos(null)).length,0);

  // Producto directo sin existencias también rechaza la comanda.
  let sinBebida=await llevar();sinBebida=await agregar(sinBebida.id,bebida,500);
  await rejects(()=>call('comandar',sinBebida.id),/BEBIDA \(falta/);
  // Un plato no ingresa por compra ni saldo inicial: solo por preparación de su receta.
  await rejects(()=>registrar({codigo:'COMPRA-PLATO',id_tipo_movimiento:entrada,id_motivo_movimiento:compra,confirmar:true,
    detalles:[{...linea,id_producto:Number(plato)}]}),/preparación de su receta/);
  // ===== Platos hechos de otros platos: Barco = Ceviche + Chicharrón + 50 g de canchita =====
  const N=Number;
  const und=(await q("SELECT id FROM pro_unidad_medida WHERE codigo='NIU'"))[0].id;
  const crudo=codigo=>product(codigo,{tipo_producto:1});
  const carta=codigo=>product(codigo,{tipo_producto:3,id_unidad_medida:und,disponible_venta:true,precio_venta:30});
  const limon=await crudo('LIMON'),pescado=await crudo('PESCADO'),cerdo=await crudo('CERDO'),canchita=await crudo('CANCHITA');
  const ceviche=await carta('CEVICHE'),chicharron=await carta('CHICHARRON'),barco=await carta('BARCO');
  let compras=0;
  const comprar=(producto,cantidad)=>registrar({codigo:'COMPRA-SUB-'+(++compras),id_tipo_movimiento:entrada,id_motivo_movimiento:compra,confirmar:true,
    detalles:[{id_producto:N(producto),id_almacen:N(almacen),id_unidad_medida:N(kg),cantidad,signo:1,costo_unitario:2}]});
  await comprar(limon,3);await comprar(pescado,10);await comprar(cerdo,10);await comprar(canchita,10);
  const crearReceta=async(producto,componentes)=>{
    const id=await insert('pro_receta',{id_producto:producto,rendimiento_porciones:1});
    for(const [ins,cantidad,unidad,extra] of componentes)
      await insert('pro_receta_insumo',{id_receta:id,id_producto_insumo:ins,cantidad,id_unidad_medida:unidad,...(extra||{})});
    return id;
  };
  const recCeviche=await crearReceta(ceviche,[[pescado,200,gramos],[limon,100,gramos]]);
  await crearReceta(chicharron,[[cerdo,300,gramos]]);
  const recBarco=await crearReceta(barco,[[ceviche,1,und],[chicharron,1,und],[canchita,50,gramos]]);
  const prep=async(codigo,rec,cantidad,item)=>(await q('SELECT prod_preparar($1::jsonb,$2) AS r',
    [JSON.stringify({codigo,id_receta:N(rec),id_almacen_destino:N(almacen),cantidad,id_pedido_detalle:item?N(item):undefined}),usuario]))[0].r.registro;
  const st=async id=>{
    const s=(await q('SELECT stock_actual,stock_reservado FROM alm_producto_stock WHERE id_producto=$1 AND id_almacen=$2',[id,almacen]))[0];
    const actual=r4(s?.stock_actual??0),reservado=r4(s?.stock_reservado??0);
    return {actual,reservado,libre:r4(actual-reservado)};
  };
  // [producto, sub-plato de origen, es plato preparado, cantidad]
  const reservas=async item=>(await q(`SELECT id_producto,id_producto_origen,es_preparado,cantidad FROM ven_pedido_reserva_insumo
    WHERE id_pedido_detalle=$1 AND cantidad>0 ORDER BY id_producto,id_producto_origen NULLS FIRST`,[item]))
    .map(r=>[N(r.id_producto),r.id_producto_origen===null?null:N(r.id_producto_origen),r.es_preparado,r4(r.cantidad)]);
  const pedir=async(producto,cantidad=1,extras={})=>{
    let p=await llevar();p=await agregar(p.id,producto,cantidad,extras);p=await call('comandar',p.id);
    return {id:p.id,item:p.items[0].id,linea:p.items[0]};
  };
  const ingCeviche=[[N(limon),N(ceviche),false,0.1],[N(pescado),N(ceviche),false,0.2]];

  // 1. Ceviche preparado para la mesa 3: el Barco no lo toma (está reservado) y usa ingredientes.
  const mesa3=await pedir(ceviche);
  check(await reservas(mesa3.item),[[N(limon),null,false,0.1],[N(pescado),null,false,0.2]]);
  await prep('CEV-M3',recCeviche,1,mesa3.item);
  check(await st(ceviche),{actual:1,reservado:1,libre:0});
  const b1=await pedir(barco);
  check(b1.linea.cantidad_reservada,0);
  check(await reservas(b1.item),[...ingCeviche,[N(cerdo),N(chicharron),false,0.3],[N(canchita),null,false,0.05]]);
  check((await st(ceviche)).reservado,1);
  // 2. La mesa 3 cancela con "Guardar en stock": queda 1 Ceviche libre.
  await call('anular',mesa3.id,null,{...anulacion,destino_preparado:'DISPONIBLE'});
  check(await st(ceviche),{actual:1,reservado:0,libre:1});
  // 3. El siguiente Barco toma ese Ceviche y solo el Chicharrón va con ingredientes.
  const b2=await pedir(barco);
  check(await reservas(b2.item),[[N(cerdo),N(chicharron),false,0.3],[N(canchita),null,false,0.05],[N(ceviche),null,true,1]]);
  check(await st(ceviche),{actual:1,reservado:1,libre:0});
  check(N((await obtener(b2.id)).items[0].subplatos_preparados),1); // El front pregunta guardar/desechar al cancelar.
  // Vista del chef: lo apartado agrupado por sub-plato.
  const vista=(await q('SELECT prod_disponibilidad($1,$2,1,$3) r',[recBarco,almacen,b2.item]))[0].r.registro;
  const fila=id=>vista.ingredientes.find(i=>N(i.id_producto)===N(id));
  check([fila(ceviche).preparado,fila(ceviche).origen,N(fila(ceviche).faltante)],[true,null,0]);
  check([fila(cerdo).origen,fila(cerdo).preparado,N(fila(cerdo).requerido)],['CHICHARRON',false,0.3]);
  check(N(vista.posibles_preparar),1);
  // Flujo 4: se consume exactamente lo apartado; el Chicharrón no entra como stock propio.
  const antesB2={cerdo:await st(cerdo),limon:await st(limon)};
  await prep('BARCO-B2',recBarco,1,b2.item);
  check(await st(ceviche),{actual:0,reservado:0,libre:0});
  check(await st(cerdo),{actual:r4(antesB2.cerdo.actual-0.3),reservado:r4(antesB2.cerdo.reservado-0.3),libre:antesB2.cerdo.libre});
  check(await st(limon),antesB2.limon);
  check(await st(chicharron),{actual:0,reservado:0,libre:0});
  check(await st(barco),{actual:1,reservado:1,libre:0});
  check(await reservas(b2.item),[]);
  // Flujo 5: entregar sale el Barco reservado.
  await call('entregar',b2.id,b2.item,{cantidad_entregada:1});
  check(await st(barco),{actual:0,reservado:0,libre:0});

  // 4. Ceviche cancelado con "Desechar": merma, y el Barco usa ingredientes.
  const mesa4=await pedir(ceviche);await prep('CEV-M4',recCeviche,1,mesa4.item);
  await call('anular',mesa4.id,null,{...anulacion,destino_preparado:'MERMA'});
  check(await st(ceviche),{actual:0,reservado:0,libre:0});
  const b4=await pedir(barco);
  check((await reservas(b4.item)).some(r=>r[2]),false);
  // 5. Un Ceviche personalizado solo se desecha; nunca llega a un Barco.
  const masLimon=await insert('pro_adicional',{id_producto:ceviche,nombre:'Más limón',precio_adicional:0,id_producto_insumo:limon,cantidad_insumo:50,id_unidad_medida:gramos});
  const pers=await pedir(ceviche,1,{adicionales:[{id_adicional:N(masLimon)}]});
  await prep('CEV-PERS',recCeviche,1,pers.item);
  await rejects(()=>call('anular',pers.id,null,{...anulacion,destino_preparado:'DISPONIBLE'}),/personalizada/);
  await call('anular',pers.id,null,{...anulacion,destino_preparado:'MERMA'});
  check(await st(ceviche),{actual:0,reservado:0,libre:0});

  // 6. Dos Ceviches anticipados libres; llegan 2 Barcos y 1 Ceviche, en ese orden.
  await prep('CEV-ANT-2',recCeviche,2);
  check(await st(ceviche),{actual:2,reservado:0,libre:2});
  check((await q('SELECT prod_listar_productos($1) r',[sucursal]))[0].r.find(p=>N(p.id)===N(ceviche)).stock_libre,2);
  const b6a=await pedir(barco),b6b=await pedir(barco),c6=await pedir(ceviche);
  for(const b of [b6a,b6b]) check((await reservas(b.item)).find(r=>r[0]===N(ceviche)),[N(ceviche),null,true,1]);
  check(c6.linea.cantidad_reservada,0);
  check(await reservas(c6.item),[[N(limon),null,false,0.1],[N(pescado),null,false,0.2]]);
  check(await st(ceviche),{actual:2,reservado:2,libre:0});
  // 7. Dos comandas compiten por 1 Ceviche libre: solo una lo toma.
  await prep('CEV-ANT-7',recCeviche,1);
  let x7=await llevar(),y7=await llevar();x7=await agregar(x7.id,barco);y7=await agregar(y7.id,barco);
  await Promise.all([call('comandar',x7.id),call('comandar',y7.id)]);
  const tomados=(await reservas(x7.items[0].id)).filter(r=>r[2]).length+(await reservas(y7.items[0].id)).filter(r=>r[2]).length;
  check(tomados,1);
  check((await st(ceviche)).libre,0);
  // 8. 1 Ceviche libre y la línea necesita 2: 1 del stock + 1 con ingredientes.
  await prep('CEV-ANT-8',recCeviche,1);
  const b8=await pedir(barco,2);
  check(await reservas(b8.item),[...ingCeviche,[N(cerdo),N(chicharron),false,0.6],[N(canchita),null,false,0.1],[N(ceviche),null,true,1]]);
  // 9. Sin Ceviche libre ni ingredientes: se rechaza y el aviso indica la ruta.
  const sinLimon=await llevar();await agregar(sinLimon.id,barco,1000);
  const e9=await call('comandar',sinLimon.id).then(()=>null,e=>e);
  check(e9?.code,'IN001');
  check(/BARCO › CEVICHE: LIMON \(falta [\d.]+ kg\)/.test(e9.message),true);
  check(/(: |, )CANCHITA \(falta/.test(e9.message),true);
  const f9=JSON.parse(e9.detail);
  check([f9.find(f=>f.producto==='LIMON').ruta,f9.find(f=>f.producto==='CERDO').ruta,f9.find(f=>f.producto==='CANCHITA').ruta],
    ['BARCO › CEVICHE','BARCO › CHICHARRON',null]);

  // 10. Barco sin preparar que tomó un Ceviche del stock: el Ceviche vuelve libre y los ingredientes se devuelven.
  const antes10={cev:await st(ceviche),cerdo:await st(cerdo)};
  await call('anular',b6a.id,null,anulacion);
  check(await st(ceviche),{actual:antes10.cev.actual,reservado:r4(antes10.cev.reservado-1),libre:r4(antes10.cev.libre+1)});
  check(await st(cerdo),{...antes10.cerdo,reservado:r4(antes10.cerdo.reservado-0.3),libre:r4(antes10.cerdo.libre+0.3)});
  check(await reservas(b6a.item),[]);
  // 11. Barco en preparación: se elige qué hacer con el Ceviche apartado y con los ingredientes.
  await call('preparacion',b6b.id,b6b.item,{estado_preparacion:3});
  await rejects(()=>call('anular_item',b6b.id,b6b.item,{...anulacion,destino_insumos:'LIBERAR'}),/sub-platos preparados/);
  await rejects(()=>call('anular_item',b6b.id,b6b.item,{...anulacion,destino_preparado:'MERMA'}),/destino_insumos/);
  const antes11={cev:await st(ceviche),cerdo:await st(cerdo)};
  await call('anular_item',b6b.id,b6b.item,{...anulacion,destino_preparado:'MERMA',destino_insumos:'LIBERAR'});
  check(await st(ceviche),{actual:r4(antes11.cev.actual-1),reservado:r4(antes11.cev.reservado-1),libre:antes11.cev.libre});
  check(await st(cerdo),{...antes11.cerdo,reservado:r4(antes11.cerdo.reservado-0.3),libre:r4(antes11.cerdo.libre+0.3)});
  check(N((await q("SELECT count(*) n FROM vw_alm_kardex WHERE motivo='MERMA' AND documento_id=$1 AND id_producto=$2",[b6b.item,ceviche]))[0].n),1);
  // Variante: guardar el Ceviche apartado y desechar los ingredientes del otro Ceviche.
  await call('preparacion',b8.id,b8.item,{estado_preparacion:3});
  const antes11b={cev:await st(ceviche),limon:await st(limon)};
  await call('anular_item',b8.id,b8.item,{...anulacion,destino_preparado:'DISPONIBLE',destino_insumos:'MERMA'});
  check((await st(ceviche)).libre,r4(antes11b.cev.libre+1));
  check(await st(limon),{actual:r4(antes11b.limon.actual-0.1),reservado:r4(antes11b.limon.reservado-0.1),libre:antes11b.limon.libre});
  // 12. Barco ya preparado y cancelado con "Guardar en stock": el próximo pedido lo toma completo.
  const b12=await pedir(barco);await prep('BARCO-12',recBarco,1,b12.item);
  await call('anular',b12.id,null,{...anulacion,destino_preparado:'DISPONIBLE'});
  check((await st(barco)).libre,1);
  const b12b=await pedir(barco);
  check(b12b.linea.cantidad_reservada,1);
  check(await reservas(b12b.item),[]);

  // 13. Barco anticipado: usa Ceviches libres y luego ingredientes; el Barco queda libre.
  await prep('CEV-ANT-13',recCeviche,1);
  const a13={cev:await st(ceviche),limon:await st(limon),pescado:await st(pescado),cerdo:await st(cerdo),canchita:await st(canchita),barco:await st(barco)};
  const posibles=(()=>{for(let n=0;;n++){const m=n+1,falta=Math.max(0,m-a13.cev.libre),e=1e-9;
    if(falta*0.1>a13.limon.libre+e||falta*0.2>a13.pescado.libre+e||m*0.3>a13.cerdo.libre+e||m*0.05>a13.canchita.libre+e) return n;}})();
  const disp13=(await q('SELECT prod_disponibilidad($1,$2,2) r',[recBarco,almacen]))[0].r.registro;
  check(N(disp13.posibles_preparar),posibles);
  check(disp13.ingredientes.find(i=>N(i.id_producto)===N(ceviche)).preparado,true);
  check(disp13.ingredientes.find(i=>N(i.id_producto)===N(cerdo)).origen,'CHICHARRON');
  const tomar13=Math.min(2,a13.cev.libre);
  await prep('BARCO-ANT-13',recBarco,2);
  check(await st(ceviche),{...a13.cev,actual:r4(a13.cev.actual-tomar13),libre:r4(a13.cev.libre-tomar13)});
  check((await st(limon)).actual,r4(a13.limon.actual-(2-tomar13)*0.1));
  check((await st(cerdo)).actual,r4(a13.cerdo.actual-0.6));
  check((await st(canchita)).actual,r4(a13.canchita.actual-0.1));
  check(await st(barco),{...a13.barco,actual:r4(a13.barco.actual+2),libre:r4(a13.barco.libre+2)});

  // 14. Sub-plato con grupos de sustitución: se rechaza al comandar y al anticipar.
  const salsa=await carta('SALSA'),aji=await crudo('AJI'),rocoto=await crudo('ROCOTO'),conSalsa=await carta('CON SALSA');
  await crearReceta(salsa,[[aji,10,gramos,{grupo_sustitucion:1}],[rocoto,10,gramos,{grupo_sustitucion:1}]]);
  const recConSalsa=await crearReceta(conSalsa,[[salsa,1,und],[canchita,10,gramos]]);
  const ps=await llevar();await agregar(ps.id,conSalsa);
  await rejects(()=>call('comandar',ps.id),/grupos de sustitución/);
  await rejects(()=>prep('CON-SALSA-ANT',recConSalsa,1),/grupos de sustitución/);

  // 15. Línea comandada sin reservas (antes de la migración): se prepara con el cálculo de respaldo.
  // Los Barcos libres del caso 13 cubren parte de la línea; queda 1 unidad por preparar.
  const legado=await pedir(barco,(await st(barco)).libre+1);
  await q(`UPDATE alm_producto_stock s SET stock_reservado=s.stock_reservado-r.cantidad FROM ven_pedido_reserva_insumo r
    WHERE r.id_pedido_detalle=$1 AND s.id_producto=r.id_producto AND s.id_almacen=r.id_almacen`,[legado.item]);
  await q('DELETE FROM ven_pedido_reserva_insumo WHERE id_pedido_detalle=$1',[legado.item]);
  const a15={cerdo:await st(cerdo),canchita:await st(canchita),barco:await st(barco)};
  await prep('BARCO-LEGADO',recBarco,1,legado.item);
  check((await st(cerdo)).actual,r4(a15.cerdo.actual-0.3));
  check((await st(canchita)).actual,r4(a15.canchita.actual-0.05));
  check((await st(barco)).reservado,r4(a15.barco.reservado+1));
  console.log('Inventario: '+checks+' comprobaciones correctas');
}
main().catch(e=>{ console.error(e);process.exitCode=1; }).finally(async()=>{
  if(pool) await pool.end();
  if(created) await admin.query('DROP DATABASE "'+name+'"');
  await admin.end();
});
