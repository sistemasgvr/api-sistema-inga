-- Listas centralizadas por código: el front las pide por código (no por id, que cambia
-- entre instalaciones), igual que las funciones SQL y la facturación SUNAT. Agrega las
-- listas que faltaban: tipos y motivos de movimiento de almacén (las usa alm_confirmar)
-- y el tipo de lote SUNAT. Re-ejecutable.
BEGIN;

INSERT INTO gen_lista (codigo, nombre, descripcion) VALUES
    ('ALM_TIPO_MOVIMIENTO', 'Tipos de movimiento de inventario', 'Entrada, salida, traslado o ajuste'),
    ('ALM_MOTIVO_MOVIMIENTO', 'Motivos de movimiento de inventario', 'valor_entero = tipo de movimiento al que aplica'),
    ('SUNAT_TIPO_LOTE', 'Tipo de lote SUNAT', 'Resumen diario de boletas o comunicación de baja')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO gen_lista_opcion (id_lista, codigo, nombre, valor_entero, orden)
SELECT l.id, v.codigo, v.nombre, v.valor, v.orden
FROM gen_lista l
JOIN (VALUES
    ('ALM_TIPO_MOVIMIENTO', 'ENTRADA', 'Entrada', 1, 1),
    ('ALM_TIPO_MOVIMIENTO', 'SALIDA', 'Salida', 2, 2),
    ('ALM_TIPO_MOVIMIENTO', 'TRASLADO', 'Traslado', 3, 3),
    ('ALM_TIPO_MOVIMIENTO', 'AJUSTE', 'Ajuste', 4, 4),
    ('ALM_MOTIVO_MOVIMIENTO', 'COMPRA', 'Compra', 1, 1),
    ('ALM_MOTIVO_MOVIMIENTO', 'PRODUCCION_ENTRADA', 'Ingreso de producción', 1, 2),
    ('ALM_MOTIVO_MOVIMIENTO', 'DEVOLUCION_INTERNA', 'Devolución interna', 1, 3),
    ('ALM_MOTIVO_MOVIMIENTO', 'DEVOLUCION_CLIENTE', 'Devolución de cliente', 1, 4),
    ('ALM_MOTIVO_MOVIMIENTO', 'SALDO_INICIAL', 'Saldo inicial', 1, 5),
    ('ALM_MOTIVO_MOVIMIENTO', 'PRODUCCION_CONSUMO', 'Consumo de producción', 2, 6),
    ('ALM_MOTIVO_MOVIMIENTO', 'VENTA', 'Entrega de venta', 2, 7),
    ('ALM_MOTIVO_MOVIMIENTO', 'CONSUMO_COCINA', 'Consumo de cocina', 2, 8),
    ('ALM_MOTIVO_MOVIMIENTO', 'CONSUMO_BARRA', 'Consumo de barra', 2, 9),
    ('ALM_MOTIVO_MOVIMIENTO', 'MERMA', 'Merma', 2, 10),
    ('ALM_MOTIVO_MOVIMIENTO', 'VENCIMIENTO', 'Vencimiento', 2, 11),
    ('ALM_MOTIVO_MOVIMIENTO', 'DETERIORO', 'Deterioro', 2, 12),
    ('ALM_MOTIVO_MOVIMIENTO', 'DEVOLUCION_PROVEEDOR', 'Devolución al proveedor', 2, 13),
    ('ALM_MOTIVO_MOVIMIENTO', 'CONSUMO_PERSONAL', 'Consumo del personal', 2, 14),
    ('ALM_MOTIVO_MOVIMIENTO', 'CORTESIA', 'Cortesía', 2, 15),
    ('ALM_MOTIVO_MOVIMIENTO', 'ABASTECIMIENTO_INTERNO', 'Abastecimiento interno', 3, 16),
    ('ALM_MOTIVO_MOVIMIENTO', 'TRANSFERENCIA_SUCURSAL', 'Transferencia entre sucursales', 3, 17),
    ('ALM_MOTIVO_MOVIMIENTO', 'CONTEO_FISICO', 'Conteo físico', 4, 18),
    ('ALM_MOTIVO_MOVIMIENTO', 'CORRECCION_REGISTRO', 'Corrección de registro', 4, 19),
    ('SUNAT_TIPO_LOTE', 'RESUMEN', 'Resumen diario', 1, 1),
    ('SUNAT_TIPO_LOTE', 'BAJA', 'Comunicación de baja', 2, 2)
) AS v(lista, codigo, nombre, valor, orden) ON v.lista = l.codigo
ON CONFLICT (id_lista, codigo) DO NOTHING;

COMMIT;

\ir ../funciones/general/listas/gen_obtener_opciones_lista_por_codigo.sql
