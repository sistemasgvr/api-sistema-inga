\set ON_ERROR_STOP on
BEGIN;
\ir migraciones/02_ven_pedidos.sql
\ir migraciones/04_inventario_unificado.sql
\ir funciones/pedidos/ven_obtener_pedido.sql
\ir funciones/pedidos/ven_bloquear_pedido.sql
\ir funciones/pedidos/ven_validar_turno_pedido.sql
\ir funciones/pedidos/ven_autorizar_anulacion.sql
\ir funciones/pedidos/ven_factor_unidad.sql
\ir funciones/pedidos/ven_recalcular_pedido.sql
\ir funciones/pedidos/ven_consumos_item.sql
\ir funciones/inventario/alm_bloquear.sql
\ir funciones/inventario/alm_confirmar.sql
\ir funciones/inventario/alm_registrar.sql
\ir funciones/inventario/alm_aplicar.sql
\ir funciones/inventario/alm_proteger_historial.sql
\ir funciones/inventario/alm_validar_insercion_detalle.sql
\ir funciones/inventario/alm_cancelar.sql
\ir funciones/pedidos/ven_reservar_item.sql
\ir funciones/pedidos/ven_pedido_entregar.sql
\ir funciones/pedidos/ven_cancelar_stock_item.sql
\ir funciones/produccion/prod_preparar.sql
\ir funciones/pedidos/ven_pedido_abrir.sql
\ir funciones/pedidos/ven_pedido_agregar_item.sql
\ir funciones/pedidos/ven_pedido_editar_item.sql
\ir funciones/pedidos/ven_pedido_anular_item.sql
\ir funciones/pedidos/ven_pedido_comandar.sql
\ir funciones/pedidos/ven_pedido_anular.sql
\ir funciones/pedidos/ven_pedido_estado.sql
\ir funciones/pedidos/ven_pedido_descartar.sql
\ir funciones/inventario/alm_listar_stock.sql
\ir funciones/inventario/alm_listar_kardex.sql
\ir funciones/inventario/alm_obtener_movimiento.sql
\ir seeds/permisos/10_pedidos.sql
\ir seeds/permisos/11_inventario.sql
COMMIT;
