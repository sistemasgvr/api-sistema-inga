-- Compras del día que ingresan stock al inventario.
-- Re-ejecutable: no falla si las columnas, constraints o el motivo ya existen.
--
-- Hasta ahora cada línea de compra apuntaba a un gdo_insumo (lista libre, sin
-- unidad fija) y nunca tocaba el almacén. Ahora una línea puede ser:
--
--   - un INSUMO libre (id_insumo): solo es gasto del día, no mueve stock.
--   - un PRODUCTO del inventario (id_producto): además del gasto, genera una
--     ENTRADA por COMPRA en el almacén indicado (id_almacen) y deja el
--     movimiento enlazado (id_alm_movimiento) para revertirlo si se anula.
--
-- Exactamente uno de los dos. Después de esto hay que volver a cargar:
--   funciones/gastos-diarios/gastos/gdo_agregar_linea.sql
--   funciones/gastos-diarios/gastos/gdo_anular_linea.sql
--   funciones/gastos-diarios/gastos/gdo_obtener_dia.sql
--   funciones/gastos-diarios/gastos/gdo_reporte_dia.sql
--   funciones/gastos-diarios/gastos/gdo_listar_productos_inventario.sql
--   funciones/gastos-diarios/insumos/*.sql

ALTER TABLE gdo_gasto_detalle ALTER COLUMN id_insumo DROP NOT NULL;
ALTER TABLE gdo_gasto_detalle ADD COLUMN IF NOT EXISTS id_producto BIGINT;
ALTER TABLE gdo_gasto_detalle ADD COLUMN IF NOT EXISTS id_almacen BIGINT;
ALTER TABLE gdo_gasto_detalle ADD COLUMN IF NOT EXISTS id_alm_movimiento BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_gdo_detalle_producto') THEN
        ALTER TABLE gdo_gasto_detalle
            ADD CONSTRAINT fk_gdo_detalle_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_gdo_detalle_almacen') THEN
        ALTER TABLE gdo_gasto_detalle
            ADD CONSTRAINT fk_gdo_detalle_almacen FOREIGN KEY (id_almacen) REFERENCES gen_almacen (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_gdo_detalle_alm_movimiento') THEN
        ALTER TABLE gdo_gasto_detalle
            ADD CONSTRAINT fk_gdo_detalle_alm_movimiento FOREIGN KEY (id_alm_movimiento) REFERENCES alm_movimiento (id);
    END IF;
    -- Una línea es insumo libre O producto de inventario, nunca ambos ni ninguno.
    -- El producto siempre entra a un almacén concreto.
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_gdo_detalle_item') THEN
        ALTER TABLE gdo_gasto_detalle ADD CONSTRAINT ck_gdo_detalle_item CHECK (
            (id_insumo IS NOT NULL AND id_producto IS NULL AND id_almacen IS NULL)
            OR (id_insumo IS NULL AND id_producto IS NOT NULL AND id_almacen IS NOT NULL)
        );
    END IF;
END $$;

COMMENT ON COLUMN gdo_gasto_detalle.id_producto IS
    'Producto del inventario comprado. Excluye a id_insumo: si viene, la compra ingresa stock al almacen.';
COMMENT ON COLUMN gdo_gasto_detalle.id_almacen IS
    'Almacen donde entra el stock. Solo en lineas de producto de inventario.';
COMMENT ON COLUMN gdo_gasto_detalle.id_alm_movimiento IS
    'Entrada de inventario (motivo COMPRA) generada por la linea. Permite revertirla si la linea se anula.';

-- Motivo de salida para revertir una compra anulada. No uso DEVOLUCION_PROVEEDOR
-- porque la mercadería no se devolvió: la compra se registró por error.
INSERT INTO gen_lista_opcion (id_lista, codigo, nombre, valor_entero)
SELECT l.id, 'ANULACION_COMPRA', 'Anulación de compra', 2
FROM gen_lista l
WHERE l.codigo = 'ALM_MOTIVO_MOVIMIENTO'
ON CONFLICT (id_lista, codigo) DO NOTHING;
