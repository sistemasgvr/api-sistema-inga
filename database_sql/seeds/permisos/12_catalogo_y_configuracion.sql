-- Permisos de catálogo (productos, categorías, almacenes), configuración
-- (estaciones, sucursales) y SUNAT.
--
-- Los seis primeros módulos ya estaban en la BD, cargados a mano y sin seed.
-- Los versiono aquí con los mismos nombres para que una instalación nueva no
-- quede sin ellos: sin productos.listar el mozo no carga la carta, y sin
-- estaciones.listar nadie imprime comandas ni elige estación al cobrar.
--
-- SUNAT es nuevo: la pantalla está en desarrollo y por ahora solo la usa el
-- menú del front.
--
-- Ejecutar después de 01_auth.sql. Es idempotente y reactiva (estado = 1)
-- cualquiera de estos permisos que se haya dado de baja.

INSERT INTO public.auth_permiso (codigo, nombre, descripcion, modulo, estado) VALUES
-- MÓDULO: Productos (también cubre recetas, adicionales y tipos de producto)
('productos.listar',   'Listar productos',         'Permite consultar el listado general de productos', 'Productos', 1),
('productos.ver',      'Ver detalle de producto',  'Permite consultar la información detallada de un producto', 'Productos', 1),
('productos.crear',    'Crear producto',           'Permite registrar nuevos productos en el sistema', 'Productos', 1),
('productos.editar',   'Editar producto',          'Permite modificar los datos de un producto existente', 'Productos', 1),
('productos.eliminar', 'Desactivar producto',      'Permite dar de baja lógica a un producto', 'Productos', 1),
('productos.activar',  'Activar producto',         'Permite reactivar un producto inactivo', 'Productos', 1),

-- MÓDULO: Categorías
('categorias.listar',   'Listar categorías',        'Permite consultar el listado general de categorías', 'Categorías', 1),
('categorias.ver',      'Ver detalle de categoría', 'Permite consultar la información detallada de una categoría', 'Categorías', 1),
('categorias.crear',    'Crear categoría',          'Permite registrar nuevas categorías en el sistema', 'Categorías', 1),
('categorias.editar',   'Editar categoría',         'Permite modificar los datos de una categoría existente', 'Categorías', 1),
('categorias.eliminar', 'Desactivar categoría',     'Permite dar de baja lógica a una categoría', 'Categorías', 1),
('categorias.activar',  'Activar categoría',        'Permite reactivar una categoría inactiva', 'Categorías', 1),

-- MÓDULO: Subcategorías
('subcategorias.listar',   'Listar subcategorías',        'Permite consultar el listado general de subcategorías', 'Subcategorías', 1),
('subcategorias.ver',      'Ver detalle de subcategoría', 'Permite consultar la información detallada de una subcategoría', 'Subcategorías', 1),
('subcategorias.crear',    'Crear subcategoría',          'Permite registrar nuevas subcategorías en el sistema', 'Subcategorías', 1),
('subcategorias.editar',   'Editar subcategoría',         'Permite modificar los datos de una subcategoría existente', 'Subcategorías', 1),
('subcategorias.eliminar', 'Desactivar subcategoría',     'Permite dar de baja lógica a una subcategoría', 'Subcategorías', 1),
('subcategorias.activar',  'Activar subcategoría',        'Permite reactivar una subcategoría inactiva', 'Subcategorías', 1),

-- MÓDULO: Almacenes
('almacenes.listar',   'Listar almacenes',        'Permite consultar el listado general de almacenes', 'Almacenes', 1),
('almacenes.ver',      'Ver detalle de almacén',  'Permite consultar la información detallada de un almacén', 'Almacenes', 1),
('almacenes.crear',    'Crear almacén',           'Permite registrar nuevos almacenes en el sistema', 'Almacenes', 1),
('almacenes.editar',   'Editar almacén',          'Permite modificar los datos de un almacén existente', 'Almacenes', 1),
('almacenes.eliminar', 'Desactivar almacén',      'Permite dar de baja lógica a un almacén', 'Almacenes', 1),
('almacenes.activar',  'Activar almacén',         'Permite reactivar un almacén inactivo', 'Almacenes', 1),

-- MÓDULO: Estaciones. La cola de impresión exige estaciones.listar y pedidos.comandar.
('estaciones.listar',   'Listar estaciones',        'Permite consultar el listado general de estaciones', 'Estaciones', 1),
('estaciones.ver',      'Ver detalle de estación',  'Permite consultar la información detallada de una estación', 'Estaciones', 1),
('estaciones.crear',    'Crear estación',           'Permite registrar nuevas estaciones en el sistema', 'Estaciones', 1),
('estaciones.editar',   'Editar estación',          'Permite modificar los datos de una estación existente', 'Estaciones', 1),
('estaciones.eliminar', 'Desactivar estación',      'Permite dar de baja lógica a una estación', 'Estaciones', 1),
('estaciones.activar',  'Activar estación',         'Permite reactivar una estación inactiva', 'Estaciones', 1),

-- MÓDULO: Sucursales
('sucursales.listar',   'Listar sucursales',        'Permite consultar el listado general de sucursales', 'Sucursales', 1),
('sucursales.ver',      'Ver detalle de sucursal',  'Permite consultar la información detallada de una sucursal', 'Sucursales', 1),
('sucursales.crear',    'Crear sucursal',           'Permite registrar nuevas sucursales en el sistema', 'Sucursales', 1),
('sucursales.editar',   'Editar sucursal',          'Permite modificar los datos de una sucursal existente', 'Sucursales', 1),
('sucursales.eliminar', 'Desactivar sucursal',      'Permite dar de baja lógica a una sucursal', 'Sucursales', 1),
('sucursales.activar',  'Activar sucursal',         'Permite reactivar una sucursal inactiva', 'Sucursales', 1),

-- MÓDULO: SUNAT
('sunat.listar',   'Consultar configuración SUNAT',  'Permite ver la configuración de facturación electrónica', 'SUNAT', 1),
('sunat.ver',      'Ver detalle SUNAT',              'Permite consultar el detalle de la configuración SUNAT', 'SUNAT', 1),
('sunat.crear',    'Crear configuración SUNAT',      'Permite registrar series y configuración SUNAT', 'SUNAT', 1),
('sunat.editar',   'Editar configuración SUNAT',     'Permite modificar series, certificado y credenciales SUNAT', 'SUNAT', 1),
('sunat.eliminar', 'Desactivar configuración SUNAT', 'Permite dar de baja una configuración SUNAT', 'SUNAT', 1),
('sunat.activar',  'Activar configuración SUNAT',    'Permite reactivar una configuración SUNAT', 'SUNAT', 1)

ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  estado = EXCLUDED.estado;
