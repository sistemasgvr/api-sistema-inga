-- Los mantenedores de categorías, subcategorías, cajas, categorías de gasto,
-- estaciones y almacenes ya no usan código: se identifican por su nombre.
-- Roles conserva su código (el sistema reconoce al administrador por 'ADMIN'),
-- pero ahora se genera a partir del nombre y deja de pedirse en el formulario.
--
-- Ejecutar con psql desde esta carpeta:  psql "$DATABASE_URL" -f 20261020_eliminar_codigo_mantenedores.sql
BEGIN;

-- Las firmas cambian (sale p_codigo), así que CREATE OR REPLACE crearía una
-- sobrecarga en vez de reemplazar. Bajo las versiones anteriores primero.
DROP FUNCTION IF EXISTS pro_crear_categoria(VARCHAR, VARCHAR, VARCHAR, BOOLEAN, INTEGER, BIGINT);
DROP FUNCTION IF EXISTS pro_actualizar_categoria(BIGINT, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, INTEGER, BIGINT);
DROP FUNCTION IF EXISTS pro_crear_sub_categoria(BIGINT, VARCHAR, VARCHAR, INTEGER, BIGINT);
DROP FUNCTION IF EXISTS pro_actualizar_sub_categoria(BIGINT, BIGINT, VARCHAR, VARCHAR, INTEGER, BIGINT);
DROP FUNCTION IF EXISTS caj_crear_caja(BIGINT, VARCHAR, VARCHAR, BIGINT);
DROP FUNCTION IF EXISTS caj_actualizar_caja(BIGINT, BIGINT, VARCHAR, VARCHAR, BIGINT);
DROP FUNCTION IF EXISTS gad_crear_categoria(VARCHAR, VARCHAR, SMALLINT, BIGINT, INTEGER, BIGINT);
DROP FUNCTION IF EXISTS gad_actualizar_categoria(BIGINT, VARCHAR, VARCHAR, SMALLINT, INTEGER, BIGINT);
DROP FUNCTION IF EXISTS gen_crear_almacen(BIGINT, VARCHAR, VARCHAR, VARCHAR, INTEGER, BOOLEAN, BIGINT);
DROP FUNCTION IF EXISTS gen_actualizar_almacen(BIGINT, BIGINT, VARCHAR, VARCHAR, VARCHAR, INTEGER, BOOLEAN, BIGINT);
DROP FUNCTION IF EXISTS gen_crear_estacion(BIGINT, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, BOOLEAN, BIGINT);
DROP FUNCTION IF EXISTS gen_actualizar_estacion(BIGINT, BIGINT, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, BOOLEAN, BIGINT);
DROP FUNCTION IF EXISTS auth_crear_rol(VARCHAR, VARCHAR, VARCHAR, BIGINT);
DROP FUNCTION IF EXISTS auth_actualizar_rol(BIGINT, VARCHAR, VARCHAR, VARCHAR, BIGINT);

-- DROP COLUMN arrastra los UNIQUE que incluían el código.
ALTER TABLE pro_categoria    DROP COLUMN IF EXISTS codigo;
ALTER TABLE pro_subcategoria DROP COLUMN IF EXISTS codigo;
ALTER TABLE caj_caja         DROP COLUMN IF EXISTS codigo;
ALTER TABLE gad_categoria    DROP COLUMN IF EXISTS codigo;
ALTER TABLE gen_almacen      DROP COLUMN IF EXISTS codigo;
ALTER TABLE gen_estacion     DROP COLUMN IF EXISTS codigo;

\ir ../funciones/productos/categoria-producto/pro_crear_categoria.sql
\ir ../funciones/productos/categoria-producto/pro_actualizar_categoria.sql
\ir ../funciones/productos/categoria-producto/pro_listar_categorias.sql
\ir ../funciones/productos/categoria-producto/pro_obtener_categoria.sql
\ir ../funciones/productos/sub-categorias/pro_crear_sub_categoria.sql
\ir ../funciones/productos/sub-categorias/pro_actualizar_sub_categoria.sql
\ir ../funciones/productos/sub-categorias/pro_listar_sub_categorias.sql
\ir ../funciones/productos/sub-categorias/pro_obtener_sub_categoria.sql
\ir ../funciones/caja/cajas/caj_crear_caja.sql
\ir ../funciones/caja/cajas/caj_actualizar_caja.sql
\ir ../funciones/caja/cajas/caj_listar_cajas.sql
\ir ../funciones/caja/cajas/caj_obtener_caja.sql
\ir ../funciones/caja/turnos/caj_listar_turnos.sql
\ir ../funciones/caja/turnos/caj_obtener_turno.sql
\ir ../funciones/gastos-administrativos/categorias/gad_crear_categoria.sql
\ir ../funciones/gastos-administrativos/categorias/gad_actualizar_categoria.sql
\ir ../funciones/gastos-administrativos/categorias/gad_listar_categorias.sql
\ir ../funciones/gastos-administrativos/categorias/gad_obtener_categoria.sql
\ir ../funciones/gastos-administrativos/gastos/gad_obtener_gasto.sql
\ir ../funciones/general/almacenes/gen_crear_almacen.sql
\ir ../funciones/general/almacenes/gen_actualizar_almacen.sql
\ir ../funciones/general/almacenes/gen_listar_almacenes.sql
\ir ../funciones/general/almacenes/gen_obtener_almacen.sql
\ir ../funciones/general/estaciones/gen_crear_estacion.sql
\ir ../funciones/general/estaciones/gen_actualizar_estacion.sql
\ir ../funciones/general/estaciones/gen_listar_estaciones.sql
\ir ../funciones/general/estaciones/gen_obtener_estacion.sql
\ir ../funciones/roles/auth_crear_rol.sql
\ir ../funciones/roles/auth_actualizar_rol.sql

COMMIT;
