-- Cubre p_cantidad de un sub-plato: primero con platos preparados LIBRES (stock_actual - stock_reservado)
-- y lo que falte con sus ingredientes, de forma recursiva. No modifica stock: agrega a p_necesidades
-- (formato de detalle de alm_aplicar + origen, ruta y preparado) y descuenta de p_libre lo tomado,
-- para que otra línea de la misma operación no tome dos veces el mismo plato. p_extra se copia a cada necesidad.
CREATE OR REPLACE FUNCTION prod_cubrir_subplato(INOUT p_necesidades JSONB,INOUT p_libre JSONB,p_producto BIGINT,p_almacen BIGINT,
  p_unidad BIGINT,p_cantidad NUMERIC,p_origen BIGINT,p_ruta TEXT,p_sucursal BIGINT,p_nivel INTEGER DEFAULT 0,p_extra JSONB DEFAULT '{}')
LANGUAGE plpgsql AS $$
DECLARE clave TEXT:=p_producto||':'||COALESCE(p_almacen,0); libre NUMERIC:=0; tomar NUMERIC:=0; resto NUMERIC; receta BIGINT; c RECORD; v NUMERIC;
BEGIN
  IF p_almacen IS NOT NULL THEN
    IF p_libre ? clave THEN libre:=(p_libre->>clave)::NUMERIC;
    ELSE
      SELECT GREATEST(s.stock_actual-s.stock_reservado,0) INTO libre FROM alm_producto_stock s
        WHERE s.id_producto=p_producto AND s.id_almacen=p_almacen AND s.estado=1;
      libre:=COALESCE(libre,0);
    END IF;
    tomar:=round(LEAST(p_cantidad,libre),4);
    IF tomar>0 THEN
      p_necesidades:=p_necesidades||jsonb_build_array(p_extra||jsonb_build_object('id_producto',p_producto,'id_almacen',p_almacen,
        'id_unidad_medida',p_unidad,'cantidad',tomar,'id_producto_origen',p_origen,'ruta',p_ruta,'preparado',true));
      p_libre:=p_libre||jsonb_build_object(clave,libre-tomar);
    END IF;
  END IF;
  resto:=round(p_cantidad-tomar,4);
  IF resto<=0 THEN RETURN; END IF;
  receta:=pro_receta_vigente(p_producto);
  IF receta IS NULL THEN RAISE EXCEPTION 'El sub-plato % no tiene receta vigente',p_ruta; END IF;
  FOR c IN SELECT * FROM pro_explotar_receta(receta,resto,NULL,p_sucursal,FALSE,p_ruta,p_nivel+1) LOOP
    IF c.es_subplato THEN
      SELECT x.p_necesidades,x.p_libre INTO p_necesidades,p_libre FROM prod_cubrir_subplato(p_necesidades,p_libre,c.id_producto,c.id_almacen,
        c.id_unidad_medida,c.cantidad,c.id_producto_origen,c.ruta,p_sucursal,p_nivel+1,p_extra) x;
    ELSE
      v:=round(c.cantidad,4);
      IF v<=0 THEN RAISE EXCEPTION 'Consumo inválido o menor a la precisión de stock en %',c.ruta; END IF;
      p_necesidades:=p_necesidades||jsonb_build_array(p_extra||jsonb_build_object('id_producto',c.id_producto,'id_almacen',c.id_almacen,
        'id_unidad_medida',c.id_unidad_medida,'cantidad',v,'id_producto_origen',c.id_producto_origen,'ruta',c.ruta,'preparado',false));
    END IF;
  END LOOP;
END $$;

-- Necesidades para preparar p_cantidad de una receta estándar sin pedido (anticipada o consulta):
-- insumos directos y sub-platos cubiertos con platos libres o ingredientes.
CREATE OR REPLACE FUNCTION prod_explosion(p_receta BIGINT,p_cantidad NUMERIC,p_sucursal BIGINT) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE necesidades JSONB:='[]'; libre JSONB:='{}'; c RECORD; v NUMERIC;
BEGIN
  FOR c IN SELECT * FROM pro_explotar_receta(p_receta,p_cantidad,NULL,p_sucursal,FALSE) LOOP
    IF c.es_subplato THEN
      SELECT x.p_necesidades,x.p_libre INTO necesidades,libre FROM prod_cubrir_subplato(necesidades,libre,c.id_producto,c.id_almacen,
        c.id_unidad_medida,c.cantidad,c.id_producto_origen,c.ruta,p_sucursal) x;
    ELSE
      v:=round(c.cantidad,4);
      IF v<=0 THEN RAISE EXCEPTION 'Consumo inválido o menor a la precisión de stock en %',c.ruta; END IF;
      necesidades:=necesidades||jsonb_build_array(jsonb_build_object('id_producto',c.id_producto,'id_almacen',c.id_almacen,
        'id_unidad_medida',c.id_unidad_medida,'cantidad',v,'id_producto_origen',NULL,'ruta',c.ruta,'preparado',false));
    END IF;
  END LOOP;
  RETURN necesidades;
END $$;
