-- Expone en listado y detalle el mismo costo unitario usado por las recetas.
-- Ejecutar con psql sobre la base de datos del sistema.
\set ON_ERROR_STOP on
BEGIN;
\ir ../funciones/productos/productos-recetas-insumos/pro_costo_unitario_insumo.sql
\ir ../funciones/productos/productos/pro_listar_productos.sql
\ir ../funciones/productos/productos/pro_obtener_producto.sql
COMMIT;
