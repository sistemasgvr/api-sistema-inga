CREATE OR REPLACE FUNCTION ven_listar_avisos_cocina(p_sucursal BIGINT,p_estacion BIGINT) RETURNS JSON LANGUAGE sql AS $$
  SELECT COALESCE(json_agg(x ORDER BY x.fecha_modificacion DESC),'[]'::JSON) FROM (
    SELECT a.id,a.id_pedido,p.codigo AS codigo_pedido,me.codigo AS codigo_mesa,a.mensaje,a.faltantes,a.estaciones,
      a.fecha_creacion,a.fecha_modificacion,trim(concat_ws(' ',u.nombres,u.apellidos)) AS usuario
    FROM ven_aviso_cocina a JOIN ven_pedido p ON p.id=a.id_pedido LEFT JOIN ven_mesa me ON me.id=p.id_mesa
    LEFT JOIN auth_usuario_datos u ON u.id=a.id_usuario_modificacion
    WHERE a.estado=1 AND a.id_sucursal=p_sucursal AND (p_estacion IS NULL OR p_estacion=ANY(a.estaciones))
    ORDER BY a.fecha_modificacion DESC LIMIT 50
  ) x;
$$;
