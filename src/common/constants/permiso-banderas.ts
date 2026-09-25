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

  ALMACENES_LISTAR: 'almacenes.listar',
  ALMACENES_VER: 'almacenes.ver',
  ALMACENES_CREAR: 'almacenes.crear',
  ALMACENES_EDITAR: 'almacenes.editar',
  ALMACENES_ACTIVAR: 'almacenes.activar',
  ALMACENES_ELIMINAR: 'almacenes.eliminar',

  ESTACIONES_LISTAR: 'estaciones.listar',
  ESTACIONES_VER: 'estaciones.ver',
  ESTACIONES_CREAR: 'estaciones.crear',
  ESTACIONES_EDITAR: 'estaciones.editar',
  ESTACIONES_ACTIVAR: 'estaciones.activar',
  ESTACIONES_ELIMINAR: 'estaciones.eliminar',

  SUCURSALES_LISTAR: 'sucursales.listar',
  SUCURSALES_VER: 'sucursales.ver',
  SUCURSALES_CREAR: 'sucursales.crear',
  SUCURSALES_EDITAR: 'sucursales.editar',
  SUCURSALES_ELIMINAR: 'sucursales.eliminar',
  SUCURSALES_ACTIVAR: 'sucursales.activar',
} as const;

export type PermisoBandera =
  (typeof PermisoBanderas)[keyof typeof PermisoBanderas];

export const TODAS_LAS_BANDERAS: PermisoBandera[] =
  Object.values(PermisoBanderas);
