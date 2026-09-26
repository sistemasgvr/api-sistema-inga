\set ON_ERROR_STOP on
BEGIN;
\ir migraciones/02_ven_pedidos.sql
\ir funciones/pedidos/ven_obtener_pedido.sql
\ir funciones/pedidos/ven_bloquear_pedido.sql
\ir funciones/pedidos/ven_validar_turno_pedido.sql
\ir funciones/pedidos/ven_autorizar_anulacion.sql
\ir funciones/pedidos/ven_factor_unidad.sql
\ir funciones/pedidos/ven_recalcular_pedido.sql
\ir funciones/pedidos/ven_consumos_item.sql
\ir funciones/pedidos/ven_pedido_abrir.sql
\ir funciones/pedidos/ven_pedido_agregar_item.sql
\ir funciones/pedidos/ven_pedido_editar_item.sql
\ir funciones/pedidos/ven_pedido_anular_item.sql
\ir funciones/pedidos/ven_pedido_comandar.sql
\ir funciones/pedidos/ven_pedido_anular.sql
\ir funciones/pedidos/ven_pedido_estado.sql
\ir seeds/permisos/10_pedidos.sql
COMMIT;
