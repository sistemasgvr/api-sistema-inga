-- Aparta los ingredientes de las unidades comandadas que no se cubrieron con platos ya preparados.
-- Un sub-plato (Ceviche dentro de un Barco) se toma primero de los platos preparados LIBRES y lo que
-- falte se reemplaza por sus ingredientes (prod_cubrir_subplato). Lo tomado se lleva en memoria para
-- que dos líneas de la misma comanda no tomen el mismo plato.
-- Todo o nada: si falta cualquier insumo (o un producto directo sin existencias) la comanda se rechaza
-- con SQLSTATE IN001; DETAIL lleva los faltantes en JSON (con la ruta del sub-plato) para el aviso a cocina.
CREATE OR REPLACE FUNCTION ven_reservar_insumos_pedido(p_items BIGINT[],p_usuario BIGINT) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE d RECORD; c RECORD; necesidades JSONB:='[]'; libre JSONB:='{}'; extra JSONB; faltantes JSONB; mensaje TEXT;
BEGIN
  PERFORM alm_bloquear();
  FOR d IN SELECT pd.id,pd.id_producto,pd.id_receta,pd.cantidad,pd.id_almacen_reserva,
      pd.cantidad-pd.cantidad_cancelada-pd.cantidad_entregada-pd.cantidad_reservada AS pendientes,
      pr.nombre AS plato,pr.id_estacion,pr.id_almacen_stock,pr.id_unidad_medida,v.id_sucursal
    FROM ven_pedido_detalle pd JOIN pro_producto pr ON pr.id=pd.id_producto JOIN ven_pedido v ON v.id=pd.id_pedido
    WHERE pd.id=ANY(p_items) ORDER BY pd.id
  LOOP
    CONTINUE WHEN d.pendientes<=0;
    extra:=jsonb_build_object('item',d.id,'directo',false,'plato',d.plato,'id_estacion',d.id_estacion);
    IF d.id_receta IS NULL THEN
      -- Producto directo (bebida, etc.): ven_reservar_item ya tomó todo lo disponible; lo que queda, falta.
      necesidades:=necesidades||jsonb_build_array(extra||jsonb_build_object('id_producto',d.id_producto,
        'id_almacen',COALESCE(d.id_almacen_reserva,d.id_almacen_stock),'id_unidad_medida',d.id_unidad_medida,
        'cantidad',d.pendientes,'directo',true,'ruta',d.plato,'preparado',false));
    ELSE
      FOR c IN SELECT x.id_producto,x.id_almacen,x.id_unidad_medida,x.es_subplato,min(x.ruta) AS ruta,
          round(sum(x.cantidad)*d.pendientes/d.cantidad,4) AS cantidad
        FROM ven_consumos_item(d.id) x GROUP BY x.id_producto,x.id_almacen,x.id_unidad_medida,x.es_subplato
      LOOP
        CONTINUE WHEN c.cantidad<=0;
        IF c.es_subplato THEN
          SELECT x.p_necesidades,x.p_libre INTO necesidades,libre FROM prod_cubrir_subplato(necesidades,libre,c.id_producto,c.id_almacen,
            c.id_unidad_medida,c.cantidad,NULL,c.ruta,d.id_sucursal,0,extra) x;
        ELSE
          necesidades:=necesidades||jsonb_build_array(extra||jsonb_build_object('id_producto',c.id_producto,'id_almacen',c.id_almacen,
            'id_unidad_medida',c.id_unidad_medida,'cantidad',c.cantidad,'id_producto_origen',NULL,'ruta',c.ruta,'preparado',false));
        END IF;
      END LOOP;
    END IF;
  END LOOP;
  IF jsonb_array_length(necesidades)=0 THEN RETURN; END IF;

  SELECT jsonb_agg(f ORDER BY f->>'producto') INTO faltantes FROM (
    SELECT jsonb_build_object('id_producto',n.id_producto,'producto',p.nombre,'unidad',u.simbolo,
      'requerido',sum(n.cantidad),'disponible',GREATEST(COALESCE(s.stock_actual-s.stock_reservado,0),0),
      'faltante',CASE WHEN bool_or(n.directo) THEN sum(n.cantidad)
        ELSE sum(n.cantidad)-GREATEST(COALESCE(s.stock_actual-s.stock_reservado,0),0) END,
      -- Solo para ingredientes de sub-platos: "Barco › Ceviche".
      'ruta',string_agg(DISTINCT n.ruta,' / ') FILTER (WHERE n.id_producto_origen IS NOT NULL),
      'platos',jsonb_agg(DISTINCT n.plato),'estaciones',jsonb_agg(DISTINCT n.id_estacion)) AS f
    FROM jsonb_to_recordset(necesidades) n(item BIGINT,id_producto BIGINT,id_almacen BIGINT,cantidad NUMERIC,
      directo BOOLEAN,plato TEXT,id_estacion BIGINT,id_producto_origen BIGINT,ruta TEXT)
    JOIN pro_producto p ON p.id=n.id_producto JOIN pro_unidad_medida u ON u.id=p.id_unidad_medida
    LEFT JOIN alm_producto_stock s ON s.id_producto=n.id_producto AND s.id_almacen=n.id_almacen AND s.estado=1
    GROUP BY n.id_producto,n.id_almacen,p.nombre,u.simbolo,s.stock_actual,s.stock_reservado
    HAVING bool_or(n.directo) OR sum(n.cantidad)>COALESCE(s.stock_actual-s.stock_reservado,0)
  ) x;
  IF faltantes IS NOT NULL THEN
    SELECT 'No hay stock suficiente para comandar: '||string_agg(format('%s%s (falta %s %s)',
      COALESCE((x->>'ruta')||': ',''),x->>'producto',
      rtrim(rtrim(round((x->>'faltante')::NUMERIC,4)::TEXT,'0'),'.'),x->>'unidad'),', ')
      INTO mensaje FROM jsonb_array_elements(faltantes) x;
    RAISE EXCEPTION USING ERRCODE='IN001',MESSAGE=mensaje,DETAIL=faltantes::TEXT;
  END IF;

  FOR c IN SELECT n.item,n.id_producto,n.id_almacen,n.id_producto_origen,bool_or(n.preparado) AS preparado,sum(n.cantidad) AS cantidad
    FROM jsonb_to_recordset(necesidades) n(item BIGINT,id_producto BIGINT,id_almacen BIGINT,cantidad NUMERIC,directo BOOLEAN,
      id_producto_origen BIGINT,preparado BOOLEAN)
    WHERE NOT n.directo GROUP BY 1,2,3,4 ORDER BY n.id_almacen,n.id_producto,n.item
  LOOP
    -- Un sub-plato preparado que se aparta suma a su stock_reservado: ningún otro pedido lo toma.
    UPDATE alm_producto_stock SET stock_reservado=stock_reservado+c.cantidad,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
      WHERE id_producto=c.id_producto AND id_almacen=c.id_almacen AND estado=1;
    INSERT INTO ven_pedido_reserva_insumo(id_pedido_detalle,id_producto,id_almacen,id_producto_origen,es_preparado,cantidad,id_usuario_creacion,id_usuario_modificacion)
      VALUES(c.item,c.id_producto,c.id_almacen,c.id_producto_origen,c.preparado,c.cantidad,p_usuario,p_usuario)
      ON CONFLICT(id_pedido_detalle,id_producto,id_almacen,(COALESCE(id_producto_origen,0))) DO UPDATE
        SET cantidad=ven_pedido_reserva_insumo.cantidad+EXCLUDED.cantidad,
        es_preparado=ven_pedido_reserva_insumo.es_preparado OR EXCLUDED.es_preparado,
        id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP;
  END LOOP;
END $$;
