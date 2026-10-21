\set ON_ERROR_STOP on
-- Pantalla de Ventas: listado de pedidos cobrados, reimpresión, cambio de
-- medio de pago y reemisión de comprobantes.
BEGIN;
\ir funciones/caja/turnos/caj_recalcular_cierre_turno.sql
\ir funciones/ventas/ven_obtener_venta.sql
\ir funciones/ventas/ven_listar_ventas.sql
\ir funciones/ventas/ven_cambiar_medio_pago.sql
\ir funciones/ventas/ven_reemitir_comprobante.sql
\ir funciones/pedidos/ven_contenido_precuenta.sql
\ir funciones/ventas/ven_reimprimir_comanda.sql
\ir funciones/ventas/ven_imprimir_comprobante.sql
\ir seeds/permisos/13_ventas.sql
COMMIT;
-- Los roles se asignan aparte (hace su propio BEGIN/COMMIT):
\ir seeds/roles/01_roles_por_proceso.sql
