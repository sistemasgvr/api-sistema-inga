DROP FUNCTION IF EXISTS alm_agrupar_detalles(p_detalles JSONB);
CREATE OR REPLACE FUNCTION alm_agrupar_detalles(p_detalles JSONB) RETURNS JSONB LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id_producto',id_producto,'id_almacen',id_almacen,
    'id_unidad_medida',id_unidad_medida,'cantidad',cantidad,'signo',signo) ORDER BY id_almacen,id_producto),'[]'::JSONB)
  FROM (SELECT x.id_producto,x.id_almacen,x.id_unidad_medida,x.signo,sum(x.cantidad) AS cantidad
    FROM jsonb_to_recordset(COALESCE(p_detalles,'[]'::JSONB)) x(id_producto BIGINT,id_almacen BIGINT,id_unidad_medida BIGINT,cantidad NUMERIC,signo SMALLINT)
    GROUP BY 1,2,3,4 HAVING sum(x.cantidad)>0) g;
$$;
