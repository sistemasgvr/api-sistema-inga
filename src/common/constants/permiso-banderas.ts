/**
 * Banderas de permiso. El nombre en BD (auth_permisos.nombre) debe coincidir con el valor.
 */
export const PermisoBanderas = {
  USUARIOS_LISTAR: 'usuarios.listar',
  USUARIOS_VER: 'usuarios.ver',
  USUARIOS_CREAR: 'usuarios.crear',
  USUARIOS_EDITAR: 'usuarios.editar',
  USUARIOS_ELIMINAR: 'usuarios.eliminar',
  USUARIOS_ACTIVAR: 'usuarios.activar',

  ROLES_LISTAR: 'roles.listar',
  ROLES_VER: 'roles.ver',
  ROLES_CREAR: 'roles.crear',
  ROLES_ACTIVAR: 'roles.activar',
  ROLES_EDITAR: 'roles.editar',
  ROLES_ELIMINAR: 'roles.eliminar',

  CATEGORIAS_LISTAR: 'categorias.listar',
  CATEGORIAS_VER: 'categorias.ver',
  CATEGORIAS_CREAR: 'categorias.crear',
  CATEGORIAS_EDITAR: 'categorias.editar',
  CATEGORIAS_ELIMINAR: 'categorias.eliminar',
  CATEGORIAS_ACTIVAR: 'categorias.activar',

  SUBCATEGORIAS_LISTAR: 'subcategorias.listar',
  SUBCATEGORIAS_VER: 'subcategorias.ver',
  SUBCATEGORIAS_CREAR: 'subcategorias.crear',
  SUBCATEGORIAS_EDITAR: 'subcategorias.editar',
  SUBCATEGORIAS_ELIMINAR: 'subcategorias.eliminar',
  SUBCATEGORIAS_ACTIVAR: 'subcategorias.activar',

  PRODUCTOS_LISTAR: 'productos.listar',
  PRODUCTOS_VER: 'productos.ver',
  PRODUCTOS_CREAR: 'productos.crear',
  PRODUCTOS_EDITAR: 'productos.editar',
  PRODUCTOS_ELIMINAR: 'productos.eliminar',
  PRODUCTOS_ACTIVAR: 'productos.activar',

  ALMACENES_LISTAR: 'ALMACENES_LISTAR',
  ALMACENES_VER: 'ALMACENES_VER',
  ALMACENES_CREAR: 'ALMACENES_CREAR',
  ALMACENES_EDITAR: 'ALMACENES_EDITAR',
  ALMACENES_ACTIVAR: 'ALMACENES_ACTIVAR',
  ALMACENES_ELIMINAR: 'ALMACENES_ELIMINAR',

  ESTACIONES_LISTAR: 'ESTACIONES_LISTAR',
  ESTACIONES_VER: 'ESTACIONES_VER',
  ESTACIONES_CREAR: 'ESTACIONES_CREAR',
  ESTACIONES_EDITAR: 'ESTACIONES_EDITAR',
  ESTACIONES_ACTIVAR: 'ESTACIONES_ACTIVAR',
  ESTACIONES_ELIMINAR: 'ESTACIONES_ELIMINAR',

  SUCURSALES_LISTAR: 'SUCURSALES_LISTAR',
  SUCURSALES_VER: 'SUCURSALES_VER',
  SUCURSALES_CREAR: 'SUCURSALES_CREAR',
  SUCURSALES_EDITAR: 'SUCURSALES_EDITAR',
  SUCURSALES_ELIMINAR: 'SUCURSALES_ELIMINAR',
  SUCURSALES_ACTIVAR: 'SUCURSALES_ACTIVAR',

  // Maestro de personas (clientes y proveedores) y sus convenios de crédito.
  //
  // Uso la convención en minúsculas con punto ('personas.listar') y no la de
  // mayúsculas con guion bajo que aparece más arriba, porque es la que está
  // realmente sembrada en la tabla auth_permiso y la que usan usuarios y roles.
  // Cuando unifiquemos las banderas, estas ya quedan del lado correcto.
  PERSONAS_LISTAR: 'personas.listar',
  PERSONAS_VER: 'personas.ver',
  PERSONAS_CREAR: 'personas.crear',
  PERSONAS_EDITAR: 'personas.editar',
  PERSONAS_ELIMINAR: 'personas.eliminar',
  PERSONAS_ACTIVAR: 'personas.activar',

  CONVENIOS_LISTAR: 'convenios.listar',
  CONVENIOS_VER: 'convenios.ver',
  CONVENIOS_CREAR: 'convenios.crear',
  CONVENIOS_EDITAR: 'convenios.editar',
  CONVENIOS_ELIMINAR: 'convenios.eliminar',
  CONVENIOS_ACTIVAR: 'convenios.activar',

  // Caja y turnos (M11).
  CAJAS_LISTAR: 'cajas.listar',
  CAJAS_VER: 'cajas.ver',
  CAJAS_CREAR: 'cajas.crear',
  CAJAS_EDITAR: 'cajas.editar',
  CAJAS_ELIMINAR: 'cajas.eliminar',
  CAJAS_ACTIVAR: 'cajas.activar',

  // Separo abrir y cerrar de listar/ver a propósito: un administrador puede
  // necesitar revisar los cierres sin poder operar la caja, y un cajero puede
  // operar la suya sin ver el histórico de todos.
  TURNOS_LISTAR: 'turnos.listar',
  TURNOS_VER: 'turnos.ver',
  TURNOS_ABRIR: 'turnos.abrir',
  TURNOS_CERRAR: 'turnos.cerrar',
  TURNOS_MOVIMIENTOS: 'turnos.movimientos',
  TURNOS_ARQUEO: 'turnos.arqueo',

  // Planilla (M17).
  TRABAJADORES_LISTAR: 'trabajadores.listar',
  TRABAJADORES_VER: 'trabajadores.ver',
  TRABAJADORES_CREAR: 'trabajadores.crear',
  TRABAJADORES_EDITAR: 'trabajadores.editar',
  TRABAJADORES_ELIMINAR: 'trabajadores.eliminar',
  TRABAJADORES_ACTIVAR: 'trabajadores.activar',

  // Separo los pagos del mantenimiento de trabajadores: el sueldo de cada
  // persona es información sensible, así que alguien puede necesitar
  // administrar el personal sin poder ver ni registrar los montos pagados.
  PLANILLA_PAGOS_LISTAR: 'planilla.pagos.listar',
  PLANILLA_PAGOS_REGISTRAR: 'planilla.pagos.registrar',
  PLANILLA_PAGOS_ANULAR: 'planilla.pagos.anular',

  // Gastos administrativos (M16).
  //
  // Las categorías son configuración: se tocan una vez y quedan. Por eso
  // agrupo su mantenimiento en un solo permiso en vez de abrir uno por acción,
  // que sería ruido en la matriz de roles.
  GASTOS_CATEGORIAS_LISTAR: 'gastos.categorias.listar',
  GASTOS_CATEGORIAS_GESTIONAR: 'gastos.categorias.gestionar',

  GASTOS_LISTAR: 'gastos.listar',
  GASTOS_REGISTRAR: 'gastos.registrar',
  GASTOS_ANULAR: 'gastos.anular',

  // Cuentas por pagar a proveedores (M15).
  //
  // Separo el cargo del abono porque son operaciones de distinto peso: el
  // cargo lo generará M14 de forma automática, mientras que el abono mueve
  // dinero real y suele hacerlo el administrador. El ajuste va aparte porque
  // reescribe el saldo a mano y debería estar reservado a pocas personas.
  CXP_LISTAR: 'cxp.listar',
  CXP_REGISTRAR_CARGO: 'cxp.cargo',
  CXP_REGISTRAR_ABONO: 'cxp.abono',
  CXP_AJUSTAR: 'cxp.ajustar',

  // Cuentas por cobrar al consorcio (M13).
  //
  // Mismo criterio que en CxP: el consumo lo generara M12 automaticamente al
  // cobrar un pedido a credito, asi que el cajero lo necesita; el abono lo
  // registra el administrador cuando la empresa paga; y el ajuste, que
  // reescribe el saldo a mano, queda para pocas personas.
  //
  // `cxc.ajustar` cubre tambien anular un movimiento, porque anular y ajustar
  // son la misma decision vista de dos formas: corregir un saldo ya escrito.
  CXC_LISTAR: 'cxc.listar',
  CXC_REGISTRAR_CONSUMO: 'cxc.consumo',
  CXC_REGISTRAR_ABONO: 'cxc.abono',
  CXC_AJUSTAR: 'cxc.ajustar',

  // Gastos diarios operativos (M14).
  //
  // `gdo.registrar` cubre también crear un insumo, porque el alcance pide que
  // el cajero pueda crearlo "al vuelo" desde el mismo formulario. Separarlo
  // haría que quien registra compras no pueda agregar lo que falta, que es
  // justo el caso que el cliente quería evitar.
  // El mantenimiento de la lista maestra (editar, dar de baja) sí va aparte.
  GDO_LISTAR: 'gdo.listar',
  GDO_REGISTRAR: 'gdo.registrar',
  GDO_ANULAR: 'gdo.anular',
  GDO_INSUMOS_GESTIONAR: 'gdo.insumos.gestionar',
} as const;

export type PermisoBandera =
  (typeof PermisoBanderas)[keyof typeof PermisoBanderas];

export const TODAS_LAS_BANDERAS: PermisoBandera[] =
  Object.values(PermisoBanderas);
