\set ON_ERROR_STOP on
-- Facturación electrónica SUNAT (APIsPERU): funciones de empresa, configuración,
-- comprobantes y lotes (resumen diario y bajas). Requiere la migración
-- migraciones/20261028_sunat_apisperu.sql (tablas y columnas).
BEGIN;
-- Empresa y distritos (vista Empresa).
\ir funciones/general/empresa/gen_crear_series_empresa.sql
\ir funciones/general/empresa/gen_empresa_crear_series.sql
\ir funciones/general/empresa/gen_obtener_empresa.sql
\ir funciones/general/empresa/gen_guardar_empresa.sql
\ir funciones/general/empresa/gen_guardar_logo_empresa.sql
\ir funciones/general/distritos/gen_obtener_distrito.sql
\ir funciones/general/distritos/gen_buscar_distritos.sql

-- Configuración SUNAT y emisor.
\ir funciones/sunat/configuracion/gen_obtener_configuracion_sunat.sql
\ir funciones/sunat/configuracion/gen_guardar_configuracion_sunat.sql
\ir funciones/sunat/configuracion/gen_guardar_certificado_sunat.sql
\ir funciones/sunat/configuracion/gen_obtener_emisor_sunat.sql
\ir funciones/sunat/configuracion/gen_listar_empresas_sunat_activas.sql

-- Comprobantes: emisión, plazos y bandeja.
\ir funciones/ventas/ven_sunat_fecha_limite.sql
\ir funciones/ventas/ven_comprobante_insertar_detalle.sql
\ir funciones/sunat/comprobantes/ven_sunat_obtener_comprobantes.sql
\ir funciones/sunat/comprobantes/ven_sunat_reservar_envio.sql
\ir funciones/sunat/comprobantes/ven_sunat_guardar_resultado.sql
\ir funciones/sunat/comprobantes/ven_sunat_guardar_archivo.sql
\ir funciones/sunat/comprobantes/ven_sunat_registrar_bitacora.sql
\ir funciones/sunat/comprobantes/ven_sunat_historial_comprobante.sql
\ir funciones/sunat/comprobantes/ven_sunat_listar_vencidos.sql
\ir funciones/sunat/comprobantes/ven_sunat_liberar_envios_colgados.sql
\ir funciones/sunat/comprobantes/ven_sunat_resumen_por_vencer.sql
\ir funciones/sunat/comprobantes/ven_sunat_listar_comprobantes_dia.sql
\ir funciones/sunat/comprobantes/ven_sunat_listar_bandeja.sql
\ir funciones/sunat/comprobantes/ven_sunat_comprobante_vigente.sql

-- Lotes: resumen diario (RC) y comunicación de baja (RA).
\ir funciones/sunat/lotes/ven_sunat_crear_lote.sql
\ir funciones/sunat/lotes/ven_sunat_registrar_ticket_lote.sql
\ir funciones/sunat/lotes/ven_sunat_resolver_lote.sql
\ir funciones/sunat/lotes/ven_sunat_marcar_consulta_lote.sql
\ir funciones/sunat/lotes/ven_sunat_listar_lotes_en_proceso.sql
\ir funciones/sunat/lotes/ven_sunat_listar_lotes.sql
\ir funciones/sunat/lotes/ven_sunat_obtener_lote.sql
\ir funciones/sunat/lotes/ven_sunat_cdr_comprobante.sql

-- Funciones existentes que cambiaron (tasa de IGV, estado SUNAT y QR del ticket).
\ir funciones/pedidos/ven_pedido_abrir.sql
\ir funciones/pedidos/ven_pedido_cobrar.sql
\ir funciones/ventas/ven_reemitir_comprobante.sql
\ir funciones/ventas/ven_ticket_comprobante.sql
\ir funciones/ventas/ven_obtener_venta.sql
\ir funciones/ventas/ven_listar_ventas.sql
COMMIT;

-- Permisos sunat.* y empresa.* (hace su propio INSERT ... ON CONFLICT).
\ir seeds/permisos/12_catalogo_y_configuracion.sql
