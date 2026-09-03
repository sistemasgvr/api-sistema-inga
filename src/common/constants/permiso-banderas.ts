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
} as const;

export type PermisoBandera =
  (typeof PermisoBanderas)[keyof typeof PermisoBanderas];

export const TODAS_LAS_BANDERAS: PermisoBandera[] =
  Object.values(PermisoBanderas);
