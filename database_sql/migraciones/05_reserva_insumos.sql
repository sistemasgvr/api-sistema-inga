-- Ejecutar dentro de instalar_inventario.sql (una única transacción).
-- Ingredientes apartados al comandar para las unidades que aún no tienen plato preparado.
-- El total por almacén/producto sigue en alm_producto_stock.stock_reservado.
CREATE TABLE IF NOT EXISTS ven_pedido_reserva_insumo (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pedido_detalle BIGINT NOT NULL REFERENCES ven_pedido_detalle(id),
  id_producto BIGINT NOT NULL REFERENCES pro_producto(id),
  id_almacen BIGINT NOT NULL REFERENCES gen_almacen(id),
  cantidad NUMERIC(14,4) NOT NULL CHECK(cantidad >= 0),
  id_usuario_creacion BIGINT NOT NULL REFERENCES auth_usuario(id),
  id_usuario_modificacion BIGINT REFERENCES auth_usuario(id),
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(id_pedido_detalle,id_producto,id_almacen)
);
CREATE INDEX IF NOT EXISTS ix_ven_reserva_insumo_stock ON ven_pedido_reserva_insumo(id_almacen,id_producto) WHERE cantidad > 0;

-- Comandas rechazadas por falta de insumos. Se registran fuera de la transacción revertida.
CREATE TABLE IF NOT EXISTS ven_aviso_cocina (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_sucursal BIGINT NOT NULL REFERENCES gen_sucursal(id),
  id_pedido BIGINT NOT NULL REFERENCES ven_pedido(id),
  estaciones BIGINT[] NOT NULL DEFAULT '{}',
  mensaje TEXT NOT NULL CHECK(btrim(mensaje) <> ''),
  faltantes JSONB NOT NULL CHECK(jsonb_typeof(faltantes) = 'array'),
  estado SMALLINT NOT NULL DEFAULT 1 CHECK(estado IN (1,2)),
  fecha_atencion TIMESTAMPTZ,
  id_usuario_atencion BIGINT REFERENCES auth_usuario(id),
  id_usuario_creacion BIGINT NOT NULL REFERENCES auth_usuario(id),
  id_usuario_modificacion BIGINT REFERENCES auth_usuario(id),
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK((estado = 2) = (fecha_atencion IS NOT NULL AND id_usuario_atencion IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS ix_ven_aviso_cocina_pendiente ON ven_aviso_cocina(id_sucursal,fecha_creacion) WHERE estado = 1;

-- La firma de cancelación incorpora el destino de los ingredientes apartados.
DROP FUNCTION IF EXISTS ven_cancelar_stock_item(BIGINT,NUMERIC,TEXT,BIGINT);
