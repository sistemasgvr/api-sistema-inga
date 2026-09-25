-- psql <conexion> -v ON_ERROR_STOP=1 -f database_sql/instalar_listas.sql
-- Sobre el esquema existente. No modifica datos de catálogos.
\set ON_ERROR_STOP on
BEGIN;
\ir funciones/general/listas/gen_listar_listas.sql
\ir funciones/general/listas/gen_obtener_lista_opciones.sql
COMMIT;
