-- =============================================================================
-- DIAGNOSTICO: que tablas del esquema faltan en la base
-- =============================================================================
--
-- Ejecutar tal cual. Si devuelve 0 filas, el esquema esta completo.
-- Si devuelve filas, ejecutar esquema_completo_reejecutable.sql.
--
-- IMPORTANTE: plpgsql NO valida las referencias a tablas al crear una funcion.
-- Un script de funciones puede correr limpio sobre tablas que no existen y
-- fallar recien al usarse. Por eso conviene correr este diagnostico ANTES.
--
-- Total de tablas esperadas: 73
-- =============================================================================

SELECT t.tabla AS tabla_faltante
FROM (VALUES
    ('alm_ajuste'),
    ('alm_ajuste_detalle'),
    ('alm_alerta'),
    ('alm_kardex'),
    ('alm_producto_stock'),
    ('alm_salida'),
    ('alm_salida_detalle'),
    ('alm_salida_evidencia'),
    ('alm_traslado'),
    ('alm_traslado_detalle'),
    ('auth_permiso'),
    ('auth_rol'),
    ('auth_rol_permiso'),
    ('auth_sesion'),
    ('auth_usuario'),
    ('auth_usuario_rol'),
    ('caj_arqueo_detalle'),
    ('caj_caja'),
    ('caj_movimiento'),
    ('caj_turno'),
    ('cli_convenio'),
    ('cli_persona'),
    ('cli_persona_direccion'),
    ('com_compra'),
    ('com_compra_detalle'),
    ('cxc_movimiento'),
    ('cxp_movimiento'),
    ('gad_categoria'),
    ('gad_gasto'),
    ('gdo_categoria'),
    ('gdo_gasto_detalle'),
    ('gdo_gasto_dia'),
    ('gdo_insumo'),
    ('gen_almacen'),
    ('gen_condicion_pago'),
    ('gen_configuracion_sunat'),
    ('gen_correlativo'),
    ('gen_cuenta_bancaria'),
    ('gen_departamento'),
    ('gen_distrito'),
    ('gen_empresa'),
    ('gen_estacion'),
    ('gen_lista'),
    ('gen_lista_opcion'),
    ('gen_pais'),
    ('gen_provincia'),
    ('gen_sucursal'),
    ('kds_ticket'),
    ('pla_pago'),
    ('pla_trabajador'),
    ('pro_adicional'),
    ('pro_categoria'),
    ('pro_producto'),
    ('pro_receta'),
    ('pro_receta_insumo'),
    ('pro_subcategoria'),
    ('pro_unidad_conversion'),
    ('pro_unidad_medida'),
    ('prod_orden'),
    ('prod_orden_detalle'),
    ('prod_requerimiento'),
    ('prod_requerimiento_detalle'),
    ('ven_comanda'),
    ('ven_comprobante'),
    ('ven_comprobante_detalle'),
    ('ven_menu_dia'),
    ('ven_menu_dia_item'),
    ('ven_mesa'),
    ('ven_pago'),
    ('ven_pedido'),
    ('ven_pedido_detalle'),
    ('ven_pedido_detalle_adicional'),
    ('ven_salon')
) AS t(tabla)
LEFT JOIN information_schema.tables i
       ON i.table_name = t.tabla
      AND i.table_schema = 'public'
WHERE i.table_name IS NULL
ORDER BY 1;
