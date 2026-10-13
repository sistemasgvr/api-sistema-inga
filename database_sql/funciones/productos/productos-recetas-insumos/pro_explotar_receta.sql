-- Componentes de p_cantidad unidades de una receta, en la unidad base de cada insumo.
-- Un componente con receta vigente es un sub-plato: con p_explotar se reemplaza por sus
-- ingredientes (recursivo); sin p_explotar se devuelve marcado es_subplato para que el
-- llamador decida si usa platos ya preparados. El guard de pro_guardar_receta_insumo evita ciclos.
-- p_seleccionados NULL = receta estándar: sin opcionales y sin grupos de sustitución.
-- id_producto_origen NULL = componente de la receta inicial; si no, el sub-plato del que sale.
CREATE OR REPLACE FUNCTION pro_explotar_receta(p_receta BIGINT,p_cantidad NUMERIC,p_seleccionados BIGINT[] DEFAULT NULL,
  p_sucursal BIGINT DEFAULT NULL,p_explotar BOOLEAN DEFAULT TRUE,p_ruta TEXT DEFAULT NULL,p_nivel INTEGER DEFAULT 0)
RETURNS TABLE(id_producto BIGINT,id_almacen BIGINT,id_unidad_medida BIGINT,cantidad NUMERIC,
  id_producto_origen BIGINT,ruta TEXT,es_subplato BOOLEAN)
LANGUAGE plpgsql AS $$
DECLARE r pro_receta%ROWTYPE; plato TEXT; v_ruta TEXT; c RECORD; sub BIGINT; v_cantidad NUMERIC; almacen_valido BOOLEAN;
BEGIN
  IF p_nivel>10 THEN RAISE EXCEPTION 'Recetas anidadas demasiado profundas en %',p_ruta; END IF;
  SELECT * INTO r FROM pro_receta WHERE id=p_receta AND estado=1;
  IF NOT FOUND OR r.rendimiento_porciones<=0 THEN RAISE EXCEPTION 'Receta inválida o inactiva'; END IF;
  SELECT nombre INTO plato FROM pro_producto WHERE id=r.id_producto;
  v_ruta:=COALESCE(p_ruta||' › ','')||plato;
  IF p_seleccionados IS NULL AND EXISTS(SELECT 1 FROM pro_receta_insumo WHERE id_receta=r.id AND estado=1 AND grupo_sustitucion IS NOT NULL) THEN
    RAISE EXCEPTION '% tiene grupos de sustitución: prepárelo desde su propio pedido para elegir la opción',v_ruta; END IF;
  IF NOT EXISTS(SELECT 1 FROM pro_receta_insumo WHERE id_receta=r.id AND estado=1) THEN
    RAISE EXCEPTION 'La receta de % no tiene insumos activos',v_ruta; END IF;

  FOR c IN SELECT ri.cantidad,ri.id_unidad_medida,ri.porcentaje_merma,p.id,p.nombre,p.estado,p.controla_stock,
      p.id_unidad_medida AS unidad_base,p.id_almacen_stock
    FROM pro_receta_insumo ri JOIN pro_producto p ON p.id=ri.id_producto_insumo
    WHERE ri.id_receta=r.id AND ri.estado=1
      AND ((ri.grupo_sustitucion IS NULL AND NOT ri.es_opcional) OR ri.id=ANY(COALESCE(p_seleccionados,'{}')))
    ORDER BY ri.orden,ri.id
  LOOP
    IF c.id=r.id_producto THEN RAISE EXCEPTION 'El plato no puede ser insumo de sí mismo'; END IF;
    IF c.estado<>1 THEN RAISE EXCEPTION 'El insumo % debe estar activo y controlar stock',c.nombre; END IF;
    v_cantidad:=c.cantidad*p_cantidad/r.rendimiento_porciones*(1+c.porcentaje_merma/100)*ven_factor_unidad(c.id_unidad_medida,c.unidad_base);
    almacen_valido:=c.controla_stock AND EXISTS(SELECT 1 FROM gen_almacen a WHERE a.id=c.id_almacen_stock AND a.estado=1
      AND (p_sucursal IS NULL OR a.id_sucursal=p_sucursal));
    sub:=pro_receta_vigente(c.id);
    IF sub IS NOT NULL AND p_explotar THEN
      RETURN QUERY SELECT * FROM pro_explotar_receta(sub,v_cantidad,NULL,p_sucursal,TRUE,v_ruta,p_nivel+1);
      CONTINUE;
    END IF;
    IF sub IS NULL THEN
      IF NOT c.controla_stock THEN RAISE EXCEPTION 'El insumo % debe estar activo y controlar stock',c.nombre; END IF;
      IF NOT almacen_valido THEN RAISE EXCEPTION 'Configure un almacén activo de esta sucursal para el producto %',c.nombre; END IF;
    END IF;
    id_producto:=c.id;
    -- Un sub-plato sin almacén válido no se toma del stock: siempre se prepara con ingredientes.
    id_almacen:=CASE WHEN almacen_valido THEN c.id_almacen_stock END;
    id_unidad_medida:=c.unidad_base;
    cantidad:=v_cantidad;
    id_producto_origen:=CASE WHEN p_nivel>0 THEN r.id_producto END;
    ruta:=v_ruta;
    es_subplato:=sub IS NOT NULL;
    RETURN NEXT;
  END LOOP;
END $$;
