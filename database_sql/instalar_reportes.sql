\set ON_ERROR_STOP on
-- Reportes y dashboard (funciones rep_*): ventas, gastos, caja, cuentas, planilla e
-- inventario por empresa, con filtro opcional de sucursal. Requiere caja, cuentas,
-- planilla, gastos e inventario instalados (y la migración multiempresa fase 4).
BEGIN;
\ir funciones/caja/turnos/caj_movimientos_externos.sql
\ir funciones/caja/turnos/caj_calcular_totales_turno.sql
\ir funciones/reportes/rep_sucursal_en_ambito.sql
\ir funciones/reportes/rep_ventas_periodo.sql
\ir funciones/reportes/rep_resumen_ventas.sql
\ir funciones/reportes/rep_productos_vendidos.sql
\ir funciones/reportes/rep_ventas_por_dia.sql
\ir funciones/reportes/rep_ventas_por_hora.sql
\ir funciones/reportes/rep_ventas_por_dia_semana.sql
\ir funciones/reportes/rep_ventas_por_tipo.sql
\ir funciones/reportes/rep_ventas_por_medio.sql
\ir funciones/reportes/rep_ventas_por_mozo.sql
\ir funciones/reportes/rep_listado_ventas.sql
\ir funciones/reportes/rep_gastos_diarios_por_dia.sql
\ir funciones/reportes/rep_gastos_diarios_por_item.sql
\ir funciones/reportes/rep_gastos_administrativos.sql
\ir funciones/reportes/rep_pagos_planilla.sql
\ir funciones/reportes/rep_turnos.sql
\ir funciones/reportes/rep_movimientos_caja.sql
\ir funciones/reportes/rep_cuentas_por_cobrar.sql
\ir funciones/reportes/rep_cuentas_por_pagar.sql
\ir funciones/reportes/rep_stock.sql
\ir funciones/reportes/rep_movimientos_inventario.sql
COMMIT;
