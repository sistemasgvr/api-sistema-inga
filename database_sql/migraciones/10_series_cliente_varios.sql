-- Series de comprobante por sucursal y cliente genérico para boletas sin DNI.
-- Re-ejecutable: no duplica series ni el cliente si ya existen.

-- Una serie activa por tipo (1 boleta, 2 factura, 3 nota de venta) en cada sucursal activa.
-- OJO: con más de una sucursal, cada local necesita series propias (B002, F002...); ajústelas a mano.
INSERT INTO gen_correlativo (id_sucursal,tipo_documento,serie,ultimo_numero,longitud)
SELECT s.id,x.tipo,x.serie,0,8
  FROM gen_sucursal s CROSS JOIN (VALUES (1,'B001'),(2,'F001'),(3,'NV01')) x(tipo,serie)
 WHERE s.estado=1
   AND NOT EXISTS(SELECT 1 FROM gen_correlativo c WHERE c.id_sucursal=s.id AND c.tipo_documento=x.tipo AND c.estado=1)
ON CONFLICT ON CONSTRAINT uq_gen_correlativo DO NOTHING;

-- ven_pedido_cobrar asigna este cliente a la boleta sin DNI y a la nota de venta.
INSERT INTO cli_persona (tipo_persona,tipo_documento,num_documento,razon_social,nombres,es_cliente)
VALUES (1,1,'00000000','CLIENTES VARIOS','CLIENTES VARIOS',TRUE)
ON CONFLICT ON CONSTRAINT uq_cli_persona_doc DO UPDATE SET es_cliente=TRUE,estado=1;
