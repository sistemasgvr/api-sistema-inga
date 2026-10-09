-- Instala estructura y funciones; no migra ni elimina los tipos existentes.
\set ON_ERROR_STOP on
BEGIN;
\ir migraciones/08_tipos_producto_estructura.sql
\ir funciones/productos/tipos-producto/pro_listar_tipos_producto.sql
\ir funciones/productos/tipos-producto/pro_crear_tipo_producto.sql
\ir funciones/productos/productos-recetas-insumos/pro_costo_unitario_insumo.sql
\ir funciones/productos/productos/pro_obtener_producto.sql
\ir funciones/productos/productos/pro_listar_productos.sql
\ir funciones/productos/productos/pro_crear_producto.sql
\ir funciones/productos/productos/pro_actualizar_producto.sql
\ir funciones/productos/productos/pro_crear_producto_stock.sql
\ir funciones/productos/productos/pro_toggle_disponibilidad_producto.sql
\ir funciones/inventario/alm_confirmar.sql
\ir funciones/pedidos/ven_consumos_item.sql
COMMIT;
