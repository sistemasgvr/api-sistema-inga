-- Producto y saldo inicial se confirman en la misma transacción.
CREATE OR REPLACE FUNCTION public.pro_crear_producto_stock(p JSONB,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE r JSON; pr pro_producto%ROWTYPE; n NUMERIC:=COALESCE((p->>'stock_inicial')::NUMERIC,0);
 minimo NUMERIC:=COALESCE((p->>'stock_minimo')::NUMERIC,0); costo NUMERIC:=COALESCE((p->>'costo_inicial')::NUMERIC,0);
BEGIN
 IF n<0 OR minimo<0 OR costo<0 OR n<>round(n,4) THEN RAISE EXCEPTION 'Stock y costo inicial inválidos'; END IF;
 IF n>0 AND (p->>'tipo_producto')::INTEGER IN (3,4,5) THEN RAISE EXCEPTION 'Los platos ingresan por preparación de su receta'; END IF;
 r:=pro_crear_producto((p->>'id_subcategoria')::BIGINT,(p->>'id_unidad_medida')::BIGINT,(p->>'codigo_interno')::VARCHAR,
  (p->>'nombre')::VARCHAR,(p->>'tipo_producto')::SMALLINT,(p->>'id_estacion')::BIGINT,(p->>'id_almacen_stock')::BIGINT,
  (p->>'descripcion')::VARCHAR,COALESCE((p->>'precio_venta')::NUMERIC,0),COALESCE((p->>'afecto_igv')::BOOLEAN,TRUE),
  COALESCE((p->>'controla_stock')::BOOLEAN,FALSE),COALESCE((p->>'disponible_venta')::BOOLEAN,TRUE),
  (p->>'tiempo_prep_min')::INTEGER,(p->>'imagen_url')::VARCHAR,p_usuario);
 IF r->>'error' IS NOT NULL THEN RETURN r; END IF;
 SELECT * INTO STRICT pr FROM pro_producto WHERE id=(r->'registro'->>'id')::BIGINT;
 IF (n>0 OR minimo>0) AND (NOT pr.controla_stock OR pr.id_almacen_stock IS NULL) THEN RAISE EXCEPTION 'Configure control de stock y almacén'; END IF;
 IF pr.controla_stock AND pr.id_almacen_stock IS NOT NULL THEN
  INSERT INTO alm_producto_stock(id_producto,id_almacen,stock_minimo,id_usuario_creacion) VALUES(pr.id,pr.id_almacen_stock,minimo,p_usuario)
   ON CONFLICT(id_almacen,id_producto) DO UPDATE SET stock_minimo=EXCLUDED.stock_minimo,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP;
 END IF;
 IF n>0 THEN
  PERFORM alm_aplicar('INICIAL-'||pr.id,'ENTRADA','SALDO_INICIAL','PRODUCTO',pr.id,
   jsonb_build_array(jsonb_build_object('id_producto',pr.id,'id_almacen',pr.id_almacen_stock,'id_unidad_medida',pr.id_unidad_medida,
    'cantidad',n,'signo',1,'costo_unitario',costo)),p_usuario);
 END IF;
 RETURN pro_obtener_producto(pr.id);
END $$;
