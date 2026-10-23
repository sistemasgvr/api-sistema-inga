\set ON_ERROR_STOP on
-- Ejecutar después de 15_notificaciones.sql. Instala las mejoras de notificaciones:
-- destinatarios, outbox, recordatorios y alertas de stock mínimo.
\ir migraciones/16_notificaciones_mejoras.sql
\ir funciones/notificaciones/not_parametro_url.sql
\ir funciones/notificaciones/not_crear.sql
\ir funciones/notificaciones/not_listar.sql
\ir funciones/notificaciones/not_contar_no_leidas.sql
\ir funciones/notificaciones/not_marcar_leida.sql
\ir funciones/notificaciones/not_marcar_todas_leidas.sql
\ir funciones/notificaciones/not_pendientes_emitir.sql
\ir funciones/notificaciones/not_depurar.sql
\ir funciones/notificaciones/not_generar_recordatorios.sql
\ir funciones/inventario/alm_alerta_stock.sql
