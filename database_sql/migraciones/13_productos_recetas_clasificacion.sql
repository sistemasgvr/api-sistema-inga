-- Aplicar con frontend y API de esta entrega. No usa CASCADE.
\set ON_ERROR_STOP on
BEGIN;
DROP FUNCTION IF EXISTS pro_crear_producto(BIGINT, BIGINT, VARCHAR, VARCHAR, SMALLINT, BIGINT, BIGINT, TEXT, NUMERIC, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER, VARCHAR, BIGINT);
DROP FUNCTION IF EXISTS pro_actualizar_producto(BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, VARCHAR, VARCHAR, TEXT, SMALLINT, NUMERIC, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER, VARCHAR, BIGINT);
DROP FUNCTION IF EXISTS cli_crear_convenio(VARCHAR, VARCHAR, BIGINT, NUMERIC, BOOLEAN, BIGINT);
DROP FUNCTION IF EXISTS cli_actualizar_convenio(BIGINT, VARCHAR, VARCHAR, BIGINT, NUMERIC, BOOLEAN, BIGINT);
\ir ../funciones/productos/productos/pro_crear_producto.sql
\ir ../funciones/productos/productos/pro_actualizar_producto.sql
\ir ../funciones/productos/productos/pro_crear_producto_stock.sql
\ir ../funciones/productos/productos/pro_listar_productos.sql
\ir ../funciones/productos/productos/pro_obtener_producto.sql
\ir ../funciones/productos/tipos-producto/pro_crear_tipo_producto.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_listar_insumos_procesados.sql
\ir ../funciones/inventario/alm_listar_stock.sql
\ir ../funciones/inventario/alm_buscar_stock.sql
\ir ../funciones/gastos-diarios/gastos/gdo_listar_productos_inventario.sql
\ir ../funciones/personas/convenios/cli_crear_convenio.sql
\ir ../funciones/personas/convenios/cli_actualizar_convenio.sql
\ir ../funciones/personas/convenios/cli_obtener_convenio.sql
\ir ../funciones/personas/convenios/cli_listar_convenios.sql
\ir ../funciones/personas/personas/cli_validar_datos_persona.sql
DROP VIEW IF EXISTS vw_stock_alerta;
CREATE OR REPLACE VIEW vw_stock_alerta AS
SELECT
    s.id,
    a.id_sucursal,
    a.tipo_almacen,
    a.nombre AS almacen,
    p.nombre AS producto,
    p.tipo_producto,
    s.stock_actual,
    s.stock_minimo,
    (s.stock_actual <= s.stock_minimo) AS alerta_activa,
    um.simbolo AS um
FROM alm_producto_stock s
JOIN gen_almacen a ON a.id = s.id_almacen
JOIN pro_producto p ON p.id = s.id_producto
JOIN pro_unidad_medida um ON um.id = p.id_unidad_medida
WHERE s.estado = 1
  AND p.controla_stock = TRUE
  AND s.stock_actual <= s.stock_minimo;
ALTER TABLE pro_producto DROP COLUMN IF EXISTS codigo_interno;
ALTER TABLE cli_convenio DROP COLUMN IF EXISTS codigo;
INSERT INTO gen_lista_opcion(id_lista,codigo,nombre,valor_entero,orden)
SELECT id,'PASAPORTE','Pasaporte',7,4 FROM gen_lista WHERE codigo='DOCUMENTO_TIPO'
ON CONFLICT (id_lista,codigo) DO UPDATE SET nombre=EXCLUDED.nombre,valor_entero=EXCLUDED.valor_entero;
UPDATE pro_tipo_producto SET permite_stock_inicial=FALSE WHERE requiere_receta AND permite_stock_inicial;
COMMIT;
