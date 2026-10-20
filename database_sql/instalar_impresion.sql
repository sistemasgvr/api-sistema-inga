\set ON_ERROR_STOP on
-- Ejecutar después de instalar_pedidos.sql. No reimprime comandas históricas.
\ir migraciones/20261003_impresion_comandas.sql
\ir migraciones/20261014_qz_configuracion.sql
\ir migraciones/20261019_impresion_principal.sql
-- Listado/detalle de estaciones con la marca de caja principal para mostrarla en la tabla.
\ir funciones/general/estaciones/gen_listar_estaciones.sql
\ir funciones/general/estaciones/gen_obtener_estacion.sql
\ir migraciones/20261020_tickets_pdf.sql
\ir migraciones/20261020_ancho_papel.sql
