BEGIN;
CREATE TABLE alm_producto_stock (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto BIGINT NOT NULL REFERENCES pro_producto (id),
    id_almacen BIGINT NOT NULL REFERENCES gen_almacen (id),
    stock_actual NUMERIC(14,4) NOT NULL DEFAULT 0,
    stock_minimo NUMERIC(14,4) NOT NULL DEFAULT 0,
    costo_promedio NUMERIC(12,4) NOT NULL DEFAULT 0,
    id_usuario_creacion BIGINT NOT NULL REFERENCES auth_usuario (id),
    id_usuario_modificacion BIGINT REFERENCES auth_usuario (id),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
);

CREATE TABLE alm_movimiento (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    fecha_movimiento TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_tipo_movimiento BIGINT NOT NULL REFERENCES gen_lista_opcion (id),  --gen_lista= 'TIPO_MOVIMIENTO'  / lista de opciones: ENTRADA, SALIDA, AJUSTE, TRASLADO
    id_motivo_movimiento BIGINT NOT NULL REFERENCES gen_lista_opcion (id), --gen_lista= 'MOTIVO_MOVIMIENTO'  / lista de opciones: COMPRA, PRODUCCION, DEVOLUCION_INTERNA, DEVOLUCION_CLIENTE / CONSUMO_COCINA , CONSUMO_BARRA , VENTA, MERMA, VENCIMIENTO, DETERIORO, DEVOLUCION_PROVEEDOR / ABASTECIMIENTO_INTERNO, TRANSFERENCIA_SUCURSAL/ CONTEO_FISICO, CORRECCION_REGISTRO
    documento_tipo VARCHAR(40),
    documento_id BIGINT,
    id_movimiento_referencia BIGINT REFERENCES alm_movimiento (id),
    observacion TEXT,
    id_usuario_creacion BIGINT NOT NULL REFERENCES auth_usuario (id),
    id_usuario_modificacion BIGINT REFERENCES auth_usuario (id),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
);

CREATE TABLE alm_movimiento_detalle (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_movimiento BIGINT NOT NULL REFERENCES alm_movimiento (id),
    numero_linea INTEGER NOT NULL, id_producto BIGINT NOT NULL REFERENCES pro_producto (id),
    id_almacen BIGINT NOT NULL REFERENCES gen_almacen (id),
    id_unidad_medida BIGINT NOT NULL REFERENCES pro_unidad_medida (id),
    cantidad NUMERIC(14,4) NOT NULL,
    signo SMALLINT NOT NULL, -- (-1: ENTRADA / AUMENTO, 1: SALIDA / DISMINUCIÓN)
    stock_anterior NUMERIC(14,4),
    stock_nuevo NUMERIC(14,4),
    costo_unitario NUMERIC(12,4),
    observacion TEXT,
    id_usuario_creacion BIGINT NOT NULL REFERENCES auth_usuario (id),
    id_usuario_modificacion BIGINT REFERENCES auth_usuario (id),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
);

COMMENT ON TABLE alm_movimiento_detalle IS
    'Afectaciones de productos por almacén. Los detalles confirmados forman el kardex.';

COMMENT ON COLUMN alm_movimiento_detalle.id_unidad_medida IS
    'Unidad base del producto; convertir otras presentaciones antes de registrar.';

COMMENT ON COLUMN alm_movimiento_detalle.cantidad IS
    'Cantidad positiva en la unidad base; signo determina si suma o resta.';

COMMENT ON COLUMN alm_movimiento_detalle.stock_contado IS
    'Existencia física encontrada en un ajuste por conteo.';

COMMENT ON COLUMN alm_movimiento_detalle.id_detalle_origen IS
    'En una entrada por traslado, identifica la salida correspondiente.';



CREATE INDEX ix_alm_stock_producto
    ON alm_producto_stock (id_producto);

CREATE INDEX ix_alm_movimiento_fecha
    ON alm_movimiento (fecha_movimiento DESC, id DESC);

CREATE INDEX ix_alm_movimiento_documento
    ON alm_movimiento (documento_tipo, documento_id)
    WHERE documento_id IS NOT NULL;

CREATE INDEX ix_alm_movimiento_referencia
    ON alm_movimiento (id_movimiento_referencia)
    WHERE id_movimiento_referencia IS NOT NULL;

CREATE INDEX ix_alm_detalle_producto_almacen
    ON alm_movimiento_detalle (id_producto, id_almacen, id_movimiento);

CREATE INDEX ix_alm_detalle_almacen
    ON alm_movimiento_detalle (id_almacen);

CREATE INDEX ix_alm_detalle_origen
    ON alm_movimiento_detalle (id_detalle_origen)
    WHERE id_detalle_origen IS NOT NULL;

COMMIT;