-- Ejecutar dentro de instalar_inventario.sql (una única transacción).
-- No inventa autores para datos históricos sin auditoría.
DO $$
BEGIN
  IF to_regclass('public.alm_movimiento') IS NULL THEN
    IF EXISTS (SELECT 1 FROM ven_pedido_detalle d JOIN ven_pedido p ON p.id=d.id_pedido
      WHERE p.estado_pedido IN (1,2,3) AND d.estado=1 AND d.stock_descontado) THEN
      RAISE EXCEPTION 'Cierre los pedidos del flujo anterior antes de migrar inventario';
    END IF;
    IF EXISTS (SELECT 1 FROM alm_producto_stock WHERE stock_reservado <> 0) THEN
      RAISE EXCEPTION 'Resuelva las reservas anteriores antes de migrar inventario';
    END IF;
  END IF;
END $$;

ALTER TABLE alm_producto_stock ALTER COLUMN id_usuario_creacion SET NOT NULL;
ALTER TABLE alm_producto_stock DROP CONSTRAINT IF EXISTS fk_alm_producto_stock_usr_creacion;
ALTER TABLE alm_producto_stock DROP CONSTRAINT IF EXISTS fk_alm_stock_creador;
ALTER TABLE alm_producto_stock ADD CONSTRAINT fk_alm_stock_creador
  FOREIGN KEY(id_usuario_creacion) REFERENCES auth_usuario(id);
ALTER TABLE alm_producto_stock DROP CONSTRAINT IF EXISTS ck_alm_stock_reserva;
ALTER TABLE alm_producto_stock ADD CONSTRAINT ck_alm_stock_reserva
  CHECK(stock_minimo >= 0 AND costo_promedio >= 0 AND stock_reservado >= 0 AND stock_reservado <= stock_actual);

CREATE TABLE IF NOT EXISTS alm_movimiento (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo VARCHAR(80) NOT NULL UNIQUE,
  fecha_movimiento TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_tipo_movimiento BIGINT NOT NULL REFERENCES gen_lista_opcion(id),
  id_motivo_movimiento BIGINT NOT NULL REFERENCES gen_lista_opcion(id),
  estado SMALLINT NOT NULL DEFAULT 1 CHECK(estado IN (1,2,3)),
  documento_tipo VARCHAR(40),
  documento_id BIGINT,
  id_movimiento_referencia BIGINT REFERENCES alm_movimiento(id),
  observacion TEXT,
  fecha_confirmacion TIMESTAMPTZ,
  id_usuario_creacion BIGINT NOT NULL REFERENCES auth_usuario(id),
  id_usuario_modificacion BIGINT REFERENCES auth_usuario(id),
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK(btrim(codigo) <> ''),
  CHECK((documento_tipo IS NULL AND documento_id IS NULL) OR
    (documento_tipo IS NOT NULL AND documento_id IS NOT NULL AND documento_id > 0)),
  CHECK(id_movimiento_referencia IS NULL OR id_movimiento_referencia <> id),
  CHECK((estado=2 AND fecha_confirmacion IS NOT NULL) OR (estado<>2 AND fecha_confirmacion IS NULL))
);

CREATE TABLE IF NOT EXISTS alm_movimiento_detalle (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_movimiento BIGINT NOT NULL REFERENCES alm_movimiento(id),
  numero_linea INTEGER NOT NULL CHECK(numero_linea > 0),
  id_producto BIGINT NOT NULL REFERENCES pro_producto(id),
  id_almacen BIGINT NOT NULL REFERENCES gen_almacen(id),
  id_unidad_medida BIGINT NOT NULL REFERENCES pro_unidad_medida(id),
  cantidad NUMERIC(14,4) NOT NULL CHECK(cantidad > 0),
  signo SMALLINT NOT NULL CHECK(signo IN (-1,1)),
  stock_anterior NUMERIC(14,4) CHECK(stock_anterior >= 0),
  stock_nuevo NUMERIC(14,4) CHECK(stock_nuevo >= 0),
  costo_unitario NUMERIC(12,4) CHECK(costo_unitario >= 0),
  observacion TEXT,
  id_usuario_creacion BIGINT NOT NULL REFERENCES auth_usuario(id),
  id_usuario_modificacion BIGINT REFERENCES auth_usuario(id),
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(id_movimiento,numero_linea),
  CHECK((stock_anterior IS NULL AND stock_nuevo IS NULL) OR
    (stock_anterior IS NOT NULL AND stock_nuevo IS NOT NULL AND stock_nuevo=stock_anterior+cantidad*signo))
);
CREATE INDEX IF NOT EXISTS ix_alm_mov_fecha ON alm_movimiento(fecha_movimiento,id);
CREATE INDEX IF NOT EXISTS ix_alm_mov_documento ON alm_movimiento(documento_tipo,documento_id);
CREATE INDEX IF NOT EXISTS ix_alm_mov_det_stock ON alm_movimiento_detalle(id_almacen,id_producto,id_movimiento);

-- La reserva pertenece a la línea del pedido; el stock guarda su total.
ALTER TABLE ven_pedido_detalle
  ADD COLUMN IF NOT EXISTS cantidad_reservada NUMERIC(14,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cantidad_entregada NUMERIC(14,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cantidad_cancelada NUMERIC(14,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS id_almacen_reserva BIGINT REFERENCES gen_almacen(id);
ALTER TABLE ven_pedido_detalle DROP CONSTRAINT IF EXISTS ck_pedido_cantidades_inventario;
ALTER TABLE ven_pedido_detalle ADD CONSTRAINT ck_pedido_cantidades_inventario CHECK(
  cantidad_reservada >= 0 AND cantidad_entregada >= 0 AND cantidad_cancelada >= 0
  AND cantidad_reservada+cantidad_entregada+cantidad_cancelada <= cantidad
  AND (cantidad_reservada=0 OR id_almacen_reserva IS NOT NULL));

ALTER TABLE prod_orden
  ADD COLUMN IF NOT EXISTS tipo_preparacion VARCHAR(20) NOT NULL DEFAULT 'ANTICIPADA'
    CHECK(tipo_preparacion IN ('ANTICIPADA','POR_PEDIDO')),
  ADD COLUMN IF NOT EXISTS id_pedido_detalle BIGINT REFERENCES ven_pedido_detalle(id);
ALTER TABLE prod_orden_detalle ADD COLUMN IF NOT EXISTS id_receta BIGINT REFERENCES pro_receta(id);
ALTER TABLE prod_orden ALTER COLUMN id_usuario_creacion SET NOT NULL;
ALTER TABLE prod_orden_detalle ALTER COLUMN id_usuario_creacion SET NOT NULL;
ALTER TABLE prod_orden DROP CONSTRAINT IF EXISTS fk_prod_orden_usr_creacion;
ALTER TABLE prod_orden DROP CONSTRAINT IF EXISTS fk_prod_orden_creador;
ALTER TABLE prod_orden ADD CONSTRAINT fk_prod_orden_creador FOREIGN KEY(id_usuario_creacion) REFERENCES auth_usuario(id);
ALTER TABLE prod_orden_detalle DROP CONSTRAINT IF EXISTS fk_prod_orden_detalle_usr_creacion;
ALTER TABLE prod_orden_detalle DROP CONSTRAINT IF EXISTS fk_prod_det_creador;
ALTER TABLE prod_orden_detalle ADD CONSTRAINT fk_prod_det_creador FOREIGN KEY(id_usuario_creacion) REFERENCES auth_usuario(id);

-- Las listas existentes se reutilizan. valor_entero del motivo indica el tipo permitido.
INSERT INTO gen_lista(codigo,nombre) VALUES
('ALM_TIPO_MOVIMIENTO','Tipos de movimiento de inventario'),
('ALM_MOTIVO_MOVIMIENTO','Motivos de movimiento de inventario') ON CONFLICT(codigo) DO NOTHING;
INSERT INTO gen_lista_opcion(id_lista,codigo,nombre,valor_entero,orden)
SELECT l.id,v.codigo,v.nombre,v.valor,v.valor FROM gen_lista l CROSS JOIN
(VALUES ('ENTRADA','Entrada',1),('SALIDA','Salida',2),('TRASLADO','Traslado',3),('AJUSTE','Ajuste',4)) v(codigo,nombre,valor)
WHERE l.codigo='ALM_TIPO_MOVIMIENTO' ON CONFLICT(id_lista,codigo) DO NOTHING;
INSERT INTO gen_lista_opcion(id_lista,codigo,nombre,valor_entero)
SELECT l.id,v.codigo,v.nombre,v.tipo FROM gen_lista l CROSS JOIN (VALUES
 ('COMPRA','Compra',1),('PRODUCCION_ENTRADA','Ingreso de producción',1),
 ('DEVOLUCION_INTERNA','Devolución interna',1),('DEVOLUCION_CLIENTE','Devolución de cliente',1),('SALDO_INICIAL','Saldo inicial',1),
 ('PRODUCCION_CONSUMO','Consumo de producción',2),('VENTA','Entrega de venta',2),
 ('CONSUMO_COCINA','Consumo de cocina',2),('CONSUMO_BARRA','Consumo de barra',2),
 ('MERMA','Merma',2),('VENCIMIENTO','Vencimiento',2),('DETERIORO','Deterioro',2),
 ('DEVOLUCION_PROVEEDOR','Devolución al proveedor',2),('CONSUMO_PERSONAL','Consumo del personal',2),('CORTESIA','Cortesía',2),
 ('ABASTECIMIENTO_INTERNO','Abastecimiento interno',3),('TRANSFERENCIA_SUCURSAL','Transferencia entre sucursales',3),
 ('CONTEO_FISICO','Conteo físico',4),('CORRECCION_REGISTRO','Corrección de registro',4)
) v(codigo,nombre,tipo) WHERE l.codigo='ALM_MOTIVO_MOVIMIENTO' ON CONFLICT(id_lista,codigo) DO NOTHING;

-- Conserva las tablas antiguas completas en otro esquema y copia el kardex sin volver a aplicar stock.
CREATE SCHEMA IF NOT EXISTS historial_almacen;
DO $$
DECLARE t TEXT; k RECORD; mov BIGINT;
BEGIN
  IF to_regclass('public.alm_kardex') IS NOT NULL THEN
    FOR k IN SELECT * FROM public.alm_kardex ORDER BY id LOOP
      INSERT INTO alm_movimiento(codigo,fecha_movimiento,id_tipo_movimiento,id_motivo_movimiento,estado,
        documento_tipo,documento_id,observacion,fecha_confirmacion,id_usuario_creacion,id_usuario_modificacion,fecha_creacion,fecha_modificacion)
      SELECT 'LEGACY-'||k.id,k.fecha_creacion,t.id,m.id,2,k.documento_tipo,k.documento_id,k.observacion,k.fecha_creacion,
        k.id_usuario_creacion,k.id_usuario_modificacion,k.fecha_creacion,k.fecha_modificacion
      FROM gen_lista_opcion t JOIN gen_lista lt ON lt.id=t.id_lista AND lt.codigo='ALM_TIPO_MOVIMIENTO'
      CROSS JOIN gen_lista_opcion m JOIN gen_lista lm ON lm.id=m.id_lista AND lm.codigo='ALM_MOTIVO_MOVIMIENTO'
      WHERE t.codigo='AJUSTE' AND m.codigo='CORRECCION_REGISTRO' RETURNING id INTO mov;
      INSERT INTO alm_movimiento_detalle(id_movimiento,numero_linea,id_producto,id_almacen,id_unidad_medida,cantidad,signo,
        stock_anterior,stock_nuevo,costo_unitario,observacion,id_usuario_creacion,id_usuario_modificacion,fecha_creacion,fecha_modificacion)
      VALUES(mov,1,k.id_producto,k.id_almacen,k.id_unidad_medida,k.cantidad,k.signo,k.stock_anterior,k.stock_nuevo,
        k.costo_unitario,'Histórico: tipo original '||k.tipo_movimiento,k.id_usuario_creacion,k.id_usuario_modificacion,k.fecha_creacion,k.fecha_modificacion);
    END LOOP;
  END IF;
  FOREACH t IN ARRAY ARRAY['alm_kardex','alm_alerta','alm_salida','alm_salida_detalle','alm_salida_evidencia',
    'alm_traslado','alm_traslado_detalle','alm_ajuste','alm_ajuste_detalle'] LOOP
    IF to_regclass('public.'||t) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I SET SCHEMA historial_almacen',t);
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE VIEW vw_alm_kardex AS
SELECT d.id,m.id AS id_movimiento,m.codigo,m.fecha_movimiento,m.fecha_confirmacion,
  t.codigo AS tipo_movimiento,o.codigo AS motivo,d.id_producto,p.nombre AS producto,d.id_almacen,a.nombre AS almacen,
  d.id_unidad_medida,u.simbolo AS unidad,
  CASE WHEN d.signo=1 THEN d.cantidad ELSE 0 END AS entrada,
  CASE WHEN d.signo=-1 THEN d.cantidad ELSE 0 END AS salida,
  d.stock_anterior,d.stock_nuevo AS saldo,d.costo_unitario,m.documento_tipo,m.documento_id,
  m.observacion,m.id_usuario_creacion,m.id_usuario_modificacion
FROM alm_movimiento m JOIN alm_movimiento_detalle d ON d.id_movimiento=m.id
JOIN gen_lista_opcion t ON t.id=m.id_tipo_movimiento JOIN gen_lista_opcion o ON o.id=m.id_motivo_movimiento
JOIN pro_producto p ON p.id=d.id_producto JOIN gen_almacen a ON a.id=d.id_almacen
JOIN pro_unidad_medida u ON u.id=d.id_unidad_medida WHERE m.estado=2;

CREATE OR REPLACE VIEW vw_stock_alerta AS
SELECT s.id,a.id_sucursal,a.tipo_almacen,a.nombre AS almacen,p.codigo_interno,p.nombre AS producto,p.tipo_producto,
  s.stock_actual,s.stock_minimo,(s.stock_actual<=s.stock_minimo) AS alerta_activa,u.simbolo AS um
FROM alm_producto_stock s JOIN gen_almacen a ON a.id=s.id_almacen JOIN pro_producto p ON p.id=s.id_producto
JOIN pro_unidad_medida u ON u.id=p.id_unidad_medida WHERE s.estado=1 AND p.controla_stock AND s.stock_actual<=s.stock_minimo;
ALTER TABLE alm_producto_stock DROP COLUMN IF EXISTS alerta_activa;
ALTER TABLE alm_producto_stock DROP COLUMN IF EXISTS fecha_ultima_alerta;
