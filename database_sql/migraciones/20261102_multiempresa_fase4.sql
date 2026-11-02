-- Multiempresa, fase 4: filtros por sucursal activa / empresa en el backend. Re-ejecutable.
--
-- Lo diario (pedidos, salón, cocina, caja y turnos, almacenes e inventario,
-- estaciones e impresión, gastos diarios) valida la sucursal de la sesión; ventas,
-- reportes, gastos administrativos, CxC/CxP, planilla, usuarios, roles, personas y
-- convenios, la empresa. Los reportes pasan de SQL en línea a funciones rep_*.
-- Incluye correcciones de las fases 2 y 3 (filtros de empresa en gastos y productos,
-- cliente del cobro por empresa) y los catálogos base de cada empresa.
BEGIN;

-- ---------------------------------------------------------------------------
-- notificaciones: aviso de una sola sucursal (cocina, pedidos, caja)
-- ---------------------------------------------------------------------------
ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS id_sucursal BIGINT;
DO $mig$ BEGIN
    ALTER TABLE notificaciones
        ADD CONSTRAINT fk_notificaciones_sucursal
        FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- CxC / CxP: los movimientos sin empresa toman la de su cliente o proveedor
-- (las funciones de la fase 3 no la llenaban; ahora lo hace un trigger).
-- ---------------------------------------------------------------------------
UPDATE cxc_movimiento m
SET id_empresa = p.id_empresa
FROM cli_persona p
WHERE p.id = m.id_persona
  AND m.id_empresa IS NULL
  AND p.id_empresa IS NOT NULL;

UPDATE cxp_movimiento m
SET id_empresa = p.id_empresa
FROM cli_persona p
WHERE p.id = m.id_persona
  AND m.id_empresa IS NULL
  AND p.id_empresa IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Vistas de saldos con id_empresa (las usan CxC, CxP y reportes)
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_cxc_saldo_persona;
CREATE VIEW vw_cxc_saldo_persona AS
SELECT
    p.id AS id_persona,
    p.id_empresa,
    COALESCE(
        NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
        p.razon_social
    ) AS nombre,
    p.num_documento,
    p.id_convenio,
    c.nombre AS convenio,
    c.limite_credito,
    COALESCE(SUM(
        CASE
            WHEN m.tipo_movimiento = 1 THEN m.monto
            WHEN m.tipo_movimiento = 2 THEN -m.monto
            ELSE m.monto
        END
    ), 0) AS saldo,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0) AS total_cargos,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0) AS total_abonos,
    MAX(m.fecha_creacion) FILTER (WHERE m.tipo_movimiento = 2) AS ultimo_abono
FROM cli_persona p
LEFT JOIN cli_convenio c ON c.id = p.id_convenio
LEFT JOIN cxc_movimiento m ON m.id_persona = p.id AND m.estado = 1
WHERE p.es_cliente = TRUE AND p.estado = 1
GROUP BY p.id, p.id_empresa, p.nombres, p.apellido_paterno, p.razon_social, p.num_documento,
         p.id_convenio, c.nombre, c.limite_credito;

-- ---------------------------------------------------------------------------
-- Vista de saldos CxP: expone id_empresa
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_cxp_saldo_proveedor;
CREATE VIEW vw_cxp_saldo_proveedor AS
SELECT
    p.id AS id_persona,
    p.id_empresa,
    COALESCE(
        NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
        p.razon_social
    ) AS nombre,
    p.num_documento,
    COALESCE(SUM(
        CASE
            WHEN m.tipo_movimiento = 1 THEN m.monto
            WHEN m.tipo_movimiento = 2 THEN -m.monto
            ELSE m.monto
        END
    ), 0) AS saldo,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0) AS total_cargos,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0) AS total_abonos,
    MAX(m.fecha_movimiento) FILTER (WHERE m.tipo_movimiento = 2) AS ultimo_abono
FROM cli_persona p
LEFT JOIN cxp_movimiento m ON m.id_persona = p.id AND m.estado = 1
WHERE p.es_proveedor = TRUE AND p.estado = 1
GROUP BY p.id, p.id_empresa, p.nombres, p.apellido_paterno, p.razon_social, p.num_documento;

COMMIT;

-- ---------------------------------------------------------------------------
-- Funciones: Empresa, almacenes y estaciones
-- ---------------------------------------------------------------------------
\ir ../funciones/general/empresa/gen_crear_catalogos_empresa.sql
\ir ../funciones/general/empresa/gen_empresa_crear_catalogos.sql
\ir ../funciones/general/estaciones/gen_obtener_estacion.sql
\ir ../funciones/general/almacenes/gen_activar_almacen.sql
\ir ../funciones/general/almacenes/gen_actualizar_almacen.sql
\ir ../funciones/general/almacenes/gen_eliminar_almacen.sql
\ir ../funciones/general/almacenes/gen_obtener_almacen.sql
\ir ../funciones/general/estaciones/gen_activar_estacion.sql
\ir ../funciones/general/estaciones/gen_actualizar_estacion.sql
\ir ../funciones/general/estaciones/gen_eliminar_estacion.sql
\ir ../funciones/general/estaciones/gen_marcar_caja_principal.sql

-- ---------------------------------------------------------------------------
-- Funciones: Inventario
-- ---------------------------------------------------------------------------
\ir ../funciones/inventario/alm_movimiento_de_sucursal.sql
\ir ../funciones/inventario/alm_alerta_stock.sql
\ir ../funciones/inventario/alm_buscar_stock.sql
\ir ../funciones/inventario/alm_cancelar.sql
\ir ../funciones/inventario/alm_confirmar.sql
\ir ../funciones/inventario/alm_listar_kardex.sql
\ir ../funciones/inventario/alm_obtener_movimiento.sql
\ir ../funciones/inventario/alm_registrar.sql

-- ---------------------------------------------------------------------------
-- Funciones: Caja y turnos
-- ---------------------------------------------------------------------------
\ir ../funciones/caja/turnos/caj_turno_de_sucursal.sql
\ir ../funciones/caja/turnos/caj_movimientos_externos.sql
\ir ../funciones/caja/turnos/caj_calcular_totales_turno.sql
\ir ../funciones/caja/cajas/caj_obtener_caja.sql
\ir ../funciones/caja/turnos/caj_obtener_turno.sql
\ir ../funciones/caja/arqueo/caj_guardar_arqueo.sql
\ir ../funciones/caja/cajas/caj_activar_caja.sql
\ir ../funciones/caja/cajas/caj_actualizar_caja.sql
\ir ../funciones/caja/cajas/caj_eliminar_caja.sql
\ir ../funciones/caja/movimientos/caj_anular_movimiento.sql
\ir ../funciones/caja/movimientos/caj_listar_movimientos.sql
\ir ../funciones/caja/movimientos/caj_registrar_movimiento.sql
\ir ../funciones/caja/turnos/caj_abrir_turno.sql
\ir ../funciones/caja/turnos/caj_cerrar_turno.sql
\ir ../funciones/caja/turnos/caj_listar_turnos.sql
\ir ../funciones/caja/turnos/caj_obtener_turno_abierto.sql
\ir ../funciones/caja/turnos/caj_resumen_turno.sql

-- ---------------------------------------------------------------------------
-- Funciones: Cuentas por cobrar
-- ---------------------------------------------------------------------------
\ir ../funciones/cuentas-por-cobrar/cxc_calcular_saldo_persona.sql
\ir ../funciones/cuentas-por-cobrar/cxc_anular_movimiento.sql
\ir ../funciones/cuentas-por-cobrar/cxc_obtener_estado_cuenta.sql
\ir ../funciones/cuentas-por-cobrar/cxc_obtener_movimiento.sql
\ir ../funciones/cuentas-por-cobrar/cxc_registrar_abono.sql
\ir ../funciones/cuentas-por-cobrar/cxc_registrar_ajuste.sql
\ir ../funciones/cuentas-por-cobrar/cxc_registrar_consumo.sql
\ir ../funciones/cuentas-por-cobrar/cxc_reporte_periodo.sql

-- ---------------------------------------------------------------------------
-- Funciones: Cuentas por pagar
-- ---------------------------------------------------------------------------
\ir ../funciones/cuentas-por-pagar/cxp_calcular_saldo_proveedor.sql
\ir ../funciones/cuentas-por-pagar/cxp_anular_movimiento.sql
\ir ../funciones/cuentas-por-pagar/cxp_listar_movimientos.sql
\ir ../funciones/cuentas-por-pagar/cxp_obtener_estado_cuenta.sql
\ir ../funciones/cuentas-por-pagar/cxp_obtener_movimiento.sql
\ir ../funciones/cuentas-por-pagar/cxp_registrar_abono.sql
\ir ../funciones/cuentas-por-pagar/cxp_registrar_ajuste.sql
\ir ../funciones/cuentas-por-pagar/cxp_registrar_cargo.sql
\ir ../funciones/cuentas-por-pagar/cxp_reporte_periodo.sql

-- ---------------------------------------------------------------------------
-- Funciones: Ventas
-- ---------------------------------------------------------------------------
\ir ../funciones/ventas/ven_pedido_de_empresa.sql
\ir ../funciones/ventas/ven_cambiar_medio_pago.sql
\ir ../funciones/ventas/ven_imprimir_comprobante.sql
\ir ../funciones/ventas/ven_listar_ventas.sql
\ir ../funciones/ventas/ven_obtener_venta.sql
\ir ../funciones/ventas/ven_reemitir_comprobante.sql
\ir ../funciones/ventas/ven_reimprimir_comanda.sql

-- ---------------------------------------------------------------------------
-- Funciones: Personas y convenios
-- ---------------------------------------------------------------------------
\ir ../funciones/personas/personas/cli_asignar_empresa_movimiento.sql

-- ---------------------------------------------------------------------------
-- Funciones: Pedidos y cocina
-- ---------------------------------------------------------------------------
\ir ../funciones/pedidos/ven_bloquear_pedido.sql
\ir ../funciones/pedidos/ven_obtener_pedido.sql
\ir ../funciones/pedidos/ven_atender_aviso_cocina.sql
\ir ../funciones/pedidos/ven_pedido_abrir.sql
\ir ../funciones/pedidos/ven_pedido_agregar_item.sql
\ir ../funciones/pedidos/ven_pedido_anular.sql
\ir ../funciones/pedidos/ven_pedido_anular_item.sql
\ir ../funciones/pedidos/ven_pedido_cobrar.sql
\ir ../funciones/pedidos/ven_pedido_comandar.sql
\ir ../funciones/pedidos/ven_pedido_descartar.sql
\ir ../funciones/pedidos/ven_pedido_editar_item.sql
\ir ../funciones/pedidos/ven_pedido_entregar.sql
\ir ../funciones/pedidos/ven_pedido_estado.sql
\ir ../funciones/pedidos/ven_pedido_precuenta.sql
\ir ../funciones/pedidos/ven_pedido_preparacion.sql

-- ---------------------------------------------------------------------------
-- Funciones: Salón y mesas
-- ---------------------------------------------------------------------------
\ir ../funciones/salon/ven_obtener_salon.sql
\ir ../funciones/salon/ven_obtener_mesa.sql
\ir ../funciones/salon/ven_estado_mesa.sql
\ir ../funciones/salon/ven_estado_salon.sql
\ir ../funciones/salon/ven_guardar_mesa.sql
\ir ../funciones/salon/ven_guardar_salon.sql
\ir ../funciones/salon/ven_sucursales_ambientes.sql

-- ---------------------------------------------------------------------------
-- Funciones: Reportes
-- ---------------------------------------------------------------------------
\ir ../funciones/reportes/rep_sucursal_en_ambito.sql
\ir ../funciones/reportes/rep_ventas_periodo.sql
\ir ../funciones/reportes/rep_cuentas_por_cobrar.sql
\ir ../funciones/reportes/rep_cuentas_por_pagar.sql
\ir ../funciones/reportes/rep_gastos_administrativos.sql
\ir ../funciones/reportes/rep_gastos_diarios_por_dia.sql
\ir ../funciones/reportes/rep_gastos_diarios_por_item.sql
\ir ../funciones/reportes/rep_listado_ventas.sql
\ir ../funciones/reportes/rep_movimientos_caja.sql
\ir ../funciones/reportes/rep_movimientos_inventario.sql
\ir ../funciones/reportes/rep_pagos_planilla.sql
\ir ../funciones/reportes/rep_productos_vendidos.sql
\ir ../funciones/reportes/rep_resumen_ventas.sql
\ir ../funciones/reportes/rep_stock.sql
\ir ../funciones/reportes/rep_turnos.sql
\ir ../funciones/reportes/rep_ventas_por_dia.sql
\ir ../funciones/reportes/rep_ventas_por_dia_semana.sql
\ir ../funciones/reportes/rep_ventas_por_hora.sql
\ir ../funciones/reportes/rep_ventas_por_medio.sql
\ir ../funciones/reportes/rep_ventas_por_mozo.sql
\ir ../funciones/reportes/rep_ventas_por_tipo.sql

-- ---------------------------------------------------------------------------
-- Funciones: Gastos administrativos
-- ---------------------------------------------------------------------------
\ir ../funciones/gastos-administrativos/categorias/gad_activar_categoria.sql
\ir ../funciones/gastos-administrativos/categorias/gad_actualizar_categoria.sql
\ir ../funciones/gastos-administrativos/categorias/gad_crear_categoria.sql
\ir ../funciones/gastos-administrativos/categorias/gad_eliminar_categoria.sql
\ir ../funciones/gastos-administrativos/categorias/gad_listar_categorias.sql
\ir ../funciones/gastos-administrativos/categorias/gad_obtener_categoria.sql
\ir ../funciones/gastos-administrativos/gastos/gad_actualizar_gasto.sql
\ir ../funciones/gastos-administrativos/gastos/gad_anular_gasto.sql
\ir ../funciones/gastos-administrativos/gastos/gad_listar_gastos.sql
\ir ../funciones/gastos-administrativos/gastos/gad_obtener_gasto.sql
\ir ../funciones/gastos-administrativos/gastos/gad_registrar_gasto.sql
\ir ../funciones/gastos-administrativos/gastos/gad_reporte_mensual.sql

-- ---------------------------------------------------------------------------
-- Funciones: Gastos diarios
-- ---------------------------------------------------------------------------
\ir ../funciones/gastos-diarios/gastos/gdo_agregar_linea.sql
\ir ../funciones/gastos-diarios/gastos/gdo_anular_linea.sql
\ir ../funciones/gastos-diarios/gastos/gdo_listar_dias.sql
\ir ../funciones/gastos-diarios/gastos/gdo_listar_productos_inventario.sql
\ir ../funciones/gastos-diarios/gastos/gdo_obtener_dia.sql
\ir ../funciones/gastos-diarios/insumos/gdo_obtener_insumo.sql

-- ---------------------------------------------------------------------------
-- Funciones: Notificaciones
-- ---------------------------------------------------------------------------
\ir ../funciones/notificaciones/not_contar_no_leidas.sql
\ir ../funciones/notificaciones/not_crear.sql
\ir ../funciones/notificaciones/not_generar_recordatorios.sql
\ir ../funciones/notificaciones/not_listar.sql
\ir ../funciones/notificaciones/not_marcar_todas_leidas.sql
\ir ../funciones/notificaciones/not_pendientes_emitir.sql

-- ---------------------------------------------------------------------------
-- Funciones: Planilla
-- ---------------------------------------------------------------------------
\ir ../funciones/planilla/pagos/pla_anular_pago.sql
\ir ../funciones/planilla/pagos/pla_listar_pagos.sql
\ir ../funciones/planilla/pagos/pla_obtener_pago.sql
\ir ../funciones/planilla/pagos/pla_registrar_pago.sql
\ir ../funciones/planilla/pagos/pla_reporte_periodo.sql
\ir ../funciones/planilla/trabajadores/pla_activar_trabajador.sql
\ir ../funciones/planilla/trabajadores/pla_eliminar_trabajador.sql
\ir ../funciones/planilla/trabajadores/pla_listar_trabajadores.sql
\ir ../funciones/planilla/trabajadores/pla_obtener_trabajador.sql

-- ---------------------------------------------------------------------------
-- Funciones: Producción
-- ---------------------------------------------------------------------------
\ir ../funciones/produccion/prod_disponibilidad.sql
\ir ../funciones/produccion/prod_preparar.sql

-- ---------------------------------------------------------------------------
-- Funciones: Productos
-- ---------------------------------------------------------------------------
\ir ../funciones/productos/productos/pro_eliminar_producto.sql

-- ---------------------------------------------------------------------------
-- Funciones: Roles
-- ---------------------------------------------------------------------------
\ir ../funciones/roles/auth_activar_rol.sql
\ir ../funciones/roles/auth_actualizar_rol.sql
\ir ../funciones/roles/auth_asignar_permisos_rol.sql
\ir ../funciones/roles/auth_asignar_roles_usuario.sql
\ir ../funciones/roles/auth_crear_rol.sql
\ir ../funciones/roles/auth_eliminar_rol.sql
\ir ../funciones/roles/auth_obtener_rol.sql

-- ---------------------------------------------------------------------------
-- Funciones: Usuarios
-- ---------------------------------------------------------------------------
\ir ../funciones/usuarios/auth_activar_usuario.sql
\ir ../funciones/usuarios/auth_actualizar_usuario.sql
\ir ../funciones/usuarios/auth_eliminar_usuario.sql
\ir ../funciones/usuarios/auth_listar_usuarios.sql
\ir ../funciones/usuarios/auth_obtener_usuario.sql

-- ---------------------------------------------------------------------------
-- Catálogos base de las empresas existentes (cliente genérico, categorías de gasto)
-- ---------------------------------------------------------------------------
SELECT gen_crear_catalogos_empresa(e.id) FROM gen_empresa e;

-- ---------------------------------------------------------------------------
-- Firmas antiguas: quita las versiones de una función cuyos argumentos son un
-- prefijo de la versión más nueva (p. ej. sin p_id_empresa). Si quedaran, una
-- llamada con menos argumentos sería ambigua («la función no es única»).
-- ---------------------------------------------------------------------------
DO $mig$
DECLARE
    f RECORD;
BEGIN
    FOR f IN
        SELECT viejo.oid::regprocedure AS firma
        FROM pg_proc viejo
        JOIN pg_proc nuevo
          ON nuevo.proname = viejo.proname
         AND nuevo.pronamespace = viejo.pronamespace
         AND nuevo.pronargs > viejo.pronargs
         AND (nuevo.proargtypes::OID[])[0:viejo.pronargs - 1] = (viejo.proargtypes::OID[])[0:viejo.pronargs - 1]
        WHERE viejo.pronamespace = 'public'::regnamespace
          AND viejo.prokind = 'f'
          AND nuevo.prokind = 'f'
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %s', f.firma);
    END LOOP;
END $mig$;
