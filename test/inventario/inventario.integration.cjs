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
  const nuevo = {id_subcategoria:subcategoria,id_unidad_medida:kg,codigo_interno:'DINAMICO',nombre:'Dinámico',
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
  check(!!(await crear({...nuevo,codigo_interno:'INVALIDO',tipo_producto:30000})).error, true);
  const product = (codigo, data = {}) => insert('pro_producto', { id_subcategoria: subcategoria, id_unidad_medida: kg, id_estacion: cocina, id_almacen_stock: almacen, codigo_interno: codigo, nombre: codigo, tipo_producto: 2, controla_stock: true, precio_venta: 11.80, ...data });
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
    codigo_interno:'ALTA-STOCK',nombre:'Nueva gaseosa',tipo_producto:6,controla_stock:true,stock_inicial:4,stock_minimo:2,costo_inicial:3};
  const crearProducto=async data=>(await q('SELECT pro_crear_producto_stock($1::jsonb,$2) r',[JSON.stringify(data),usuario]))[0].r;
  const creado=(await crearProducto(alta)).registro;
  check(!!creado,true);
  check(await stock(creado.id),4);
  const stockInicial=(await q('SELECT * FROM alm_producto_stock WHERE id_producto=$1',[creado.id]))[0];
  check(Number(stockInicial.stock_minimo),2);
  check(Number(stockInicial.costo_promedio),3);
  check(Number(stockInicial.id_usuario_creacion),Number(usuario));
  check(Number((await q("SELECT count(*) n FROM vw_alm_kardex WHERE documento_tipo='PRODUCTO' AND documento_id=$1",[creado.id]))[0].n),1);
  await rejects(()=>crearProducto({...alta,codigo_interno:'PLATO-INVALIDO',tipo_producto:3}),/no permite stock/);
  const saldoInicial=await opcion('ALM_MOTIVO_MOVIMIENTO','SALDO_INICIAL');
  await q('UPDATE gen_lista_opcion SET estado=0 WHERE id=$1',[saldoInicial]);
  await rejects(()=>crearProducto({...alta,codigo_interno:'ALTA-ROLLBACK'}),/catálogo|Catálogo|motivo|Motivo/);
  check(Number((await q("SELECT count(*) n FROM pro_producto WHERE codigo_interno='ALTA-ROLLBACK'"))[0].n),0);
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
  const avisos=async estacion=>(await q('SELECT ven_listar_avisos_cocina($1,$2) r',[sucursal,estacion]))[0].r;
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
  console.log('Inventario: '+checks+' comprobaciones correctas');
}
main().catch(e=>{ console.error(e);process.exitCode=1; }).finally(async()=>{
  if(pool) await pool.end();
  if(created) await admin.query('DROP DATABASE "'+name+'"');
  await admin.end();
});
