CREATE TABLE IF NOT EXISTS alm_kardex (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen              BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    tipo_movimiento         SMALLINT     NOT NULL,
    signo                   SMALLINT     NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    stock_anterior          NUMERIC(14, 4) NOT NULL,
    stock_nuevo             NUMERIC(14, 4) NOT NULL,
    costo_unitario          NUMERIC(12, 4),
    documento_tipo          VARCHAR(40),
    documento_id            BIGINT,
    observacion             TEXT,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_kardex_signo CHECK (signo IN (-1, 1)),
    CONSTRAINT ck_kardex_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_kardex_almacen FOREIGN KEY (id_almacen) REFERENCES gen_almacen (id),
    CONSTRAINT fk_kardex_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_kardex_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id),
    CONSTRAINT fk_alm_kardex_usr_creacion FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuario (id) ON DELETE SET NULL,
    CONSTRAINT fk_alm_kardex_usr_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuario (id) ON DELETE SET NULL
);

COMMENT ON COLUMN alm_kardex.documento_tipo IS
    'Origen polimórfico: COMPRA, SALIDA, PRODUCCION, PEDIDO_DETALLE, TRASLADO, AJUSTE. documento_id = PK de esa tabla.';

-- Utilidad: aviso de stock bajo para chef y administración.
CREATE TABLE IF NOT EXISTS alm_alerta (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen              BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    stock_al_momento        NUMERIC(14, 4) NOT NULL,
    stock_minimo            NUMERIC(14, 4) NOT NULL,
    vista_chef              BOOLEAN      NOT NULL DEFAULT FALSE,
    vista_admin             BOOLEAN      NOT NULL DEFAULT FALSE,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alerta_almacen FOREIGN KEY (id_almacen) REFERENCES gen_almacen (id),
    CONSTRAINT fk_alerta_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id)
);

