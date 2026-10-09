-- Ejecutar completo en el editor SQL. Conserva los costos existentes.
BEGIN;
-- Costo unitario de un producto, para valorar recetas.

CREATE OR REPLACE FUNCTION pro_costo_unitario_insumo(p_id_producto BIGINT)
RETURNS NUMERIC(14, 4)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_costo NUMERIC(14, 4);
    v_id_almacen_stock BIGINT;
BEGIN
    IF p_id_producto IS NULL THEN
        RETURN 0;
    END IF;

    -- Plato con receta vigente: vale su costo de receta.
    IF EXISTS (
        SELECT 1 FROM pro_receta r
        WHERE r.id_producto = p_id_producto AND r.estado = 1 AND r.vigente
    ) THEN
        SELECT COALESCE(costo_receta_calculado, 0) INTO v_costo
        FROM pro_producto WHERE id = p_id_producto;
        RETURN v_costo;
    END IF;

    -- Insumo crudo: promedio ponderado del almacén donde está almacenado.
    SELECT id_almacen_stock INTO v_id_almacen_stock
    FROM pro_producto WHERE id = p_id_producto;

    SELECT COALESCE(s.costo_promedio, 0) INTO v_costo
    FROM alm_producto_stock s
    WHERE s.id_producto = p_id_producto
      AND s.estado = 1
      AND s.id_almacen = v_id_almacen_stock
    LIMIT 1;

    RETURN COALESCE(v_costo, 0);
END;
$function$;
CREATE OR REPLACE FUNCTION pro_listar_productos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_tipo_producto SMALLINT DEFAULT NULL,
    p_id_subcategoria BIGINT DEFAULT NULL,
    p_id_categoria BIGINT DEFAULT NULL,
    p_estado INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_cant_total BIGINT;
    v_cant_activos BIGINT;
    v_cant_inactivos BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE p.estado = 1),
        COUNT(*) FILTER (WHERE p.estado = 0)
    INTO v_cant_total, v_cant_activos, v_cant_inactivos
    FROM pro_producto p
    LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
    LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
    WHERE (p_tipo_producto IS NULL OR p.tipo_producto = p_tipo_producto)
      AND (p_id_subcategoria IS NULL OR p.id_subcategoria = p_id_subcategoria)
      AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
      AND (
          p_busqueda = ''
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COUNT(*) INTO v_total
    FROM pro_producto p
    LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
    LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
    WHERE (p_estado IS NULL OR p.estado = p_estado)
      AND (p_tipo_producto IS NULL OR p.tipo_producto = p_tipo_producto)
      AND (p_id_subcategoria IS NULL OR p.id_subcategoria = p_id_subcategoria)
      AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
      AND (
          p_busqueda = ''
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.id_subcategoria,
            sc.nombre AS nombre_subcategoria,
            sc.id_categoria,
            c.nombre AS nombre_categoria,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            um.simbolo AS simbolo_unidad,
            p.id_estacion,
            e.nombre AS nombre_estacion,
            p.id_almacen_stock,
            a.nombre AS nombre_almacen,
            p.codigo_interno,
            p.nombre,
            p.imagen_url,
            p.tipo_producto,
            tp.nombre AS nombre_tipo_producto,
            tp.permite_venta,
            tp.requiere_receta,
            tp.requiere_estacion,
            tp.permite_stock_inicial,
            p.precio_venta,
            p.costo_receta_calculado,
            pro_costo_unitario_insumo(p.id) AS costo_unitario,
            p.controla_stock,
            p.disponible_venta,
            p.afecto_igv,
            p.descripcion,
            p.tiempo_prep_min,
            p.estado,
            p.fecha_creacion,
            p.fecha_modificacion
        FROM pro_producto p
        LEFT JOIN pro_tipo_producto tp ON tp.id = p.tipo_producto
        LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
        LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN pro_unidad_medida um ON p.id_unidad_medida = um.id
        LEFT JOIN gen_estacion e ON p.id_estacion = e.id
        LEFT JOIN gen_almacen a ON p.id_almacen_stock = a.id
        WHERE (p_estado IS NULL OR p.estado = p_estado)
          AND (p_tipo_producto IS NULL OR p.tipo_producto = p_tipo_producto)
          AND (p_id_subcategoria IS NULL OR p.id_subcategoria = p_id_subcategoria)
          AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
          AND (
              p_busqueda = ''
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.codigo_interno) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY p.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', json_build_object(
            'total', v_cant_total,
            'activos', v_cant_activos,
            'inactivos', v_cant_inactivos
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION pro_obtener_producto(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            p.id,
            p.id_subcategoria,
            sc.nombre AS nombre_subcategoria,
            sc.id_categoria,
            c.nombre AS nombre_categoria,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            um.simbolo AS simbolo_unidad,
            p.id_estacion,
            e.nombre AS nombre_estacion,
            p.id_almacen_stock,
            a.nombre AS nombre_almacen,
            p.codigo_interno,
            p.nombre,
            p.descripcion,
            p.tipo_producto,
            tp.nombre AS nombre_tipo_producto,
            tp.permite_venta,
            tp.requiere_receta,
            tp.requiere_estacion,
            tp.permite_stock_inicial,
            p.precio_venta,
            p.costo_receta_calculado,
            pro_costo_unitario_insumo(p.id) AS costo_unitario,
            p.afecto_igv,
            p.controla_stock,
            p.disponible_venta,
            p.tiempo_prep_min,
            p.imagen_url,
            p.estado,
            p.fecha_creacion,
            p.fecha_modificacion,
            p.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            p.id_usuario_modificacion,
            umod.nombres AS nombre_usuario_modificacion
        FROM pro_producto p
        LEFT JOIN pro_tipo_producto tp ON tp.id = p.tipo_producto
        LEFT JOIN pro_subcategoria sc ON p.id_subcategoria = sc.id
        LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN pro_unidad_medida um ON p.id_unidad_medida = um.id
        LEFT JOIN gen_estacion e ON p.id_estacion = e.id
        LEFT JOIN gen_almacen a ON p.id_almacen_stock = a.id
        LEFT JOIN auth_usuario_datos uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario_datos umod ON p.id_usuario_modificacion = umod.id
        WHERE p.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- Producto y saldo inicial se confirman en la misma transacción.
CREATE OR REPLACE FUNCTION public.pro_crear_producto_stock(p JSONB,p_usuario BIGINT) RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE r JSON; pr pro_producto%ROWTYPE; n NUMERIC:=COALESCE((p->>'stock_inicial')::NUMERIC,0);
 minimo NUMERIC:=COALESCE((p->>'stock_minimo')::NUMERIC,0); costo NUMERIC:=COALESCE((p->>'costo_inicial')::NUMERIC,0);
BEGIN
 IF n<0 OR minimo<0 OR costo<0 OR n<>round(n,4) THEN RAISE EXCEPTION 'Stock y costo inicial inválidos'; END IF;
 IF (n>0 OR costo>0) AND NOT EXISTS (SELECT 1 FROM pro_tipo_producto WHERE id=(p->>'tipo_producto')::INTEGER AND estado=1 AND permite_stock_inicial) THEN
   RAISE EXCEPTION 'Este tipo no permite stock ni costo inicial'; END IF;
 r:=pro_crear_producto((p->>'id_subcategoria')::BIGINT,(p->>'id_unidad_medida')::BIGINT,(p->>'codigo_interno')::VARCHAR,
  (p->>'nombre')::VARCHAR,(p->>'tipo_producto')::SMALLINT,(p->>'id_estacion')::BIGINT,(p->>'id_almacen_stock')::BIGINT,
  (p->>'descripcion')::VARCHAR,COALESCE((p->>'precio_venta')::NUMERIC,0),COALESCE((p->>'afecto_igv')::BOOLEAN,TRUE),
  COALESCE((p->>'controla_stock')::BOOLEAN,FALSE),COALESCE((p->>'disponible_venta')::BOOLEAN,TRUE),
  (p->>'tiempo_prep_min')::INTEGER,(p->>'imagen_url')::VARCHAR,p_usuario);
 IF r->>'error' IS NOT NULL THEN RETURN r; END IF;
 SELECT * INTO STRICT pr FROM pro_producto WHERE id=(r->'registro'->>'id')::BIGINT;
 IF (n>0 OR minimo>0 OR costo>0) AND (NOT pr.controla_stock OR pr.id_almacen_stock IS NULL) THEN RAISE EXCEPTION 'Configure control de stock y almacén'; END IF;
 IF pr.controla_stock AND pr.id_almacen_stock IS NOT NULL THEN
  INSERT INTO alm_producto_stock(id_producto,id_almacen,stock_minimo,id_usuario_creacion) VALUES(pr.id,pr.id_almacen_stock,minimo,p_usuario)
   ON CONFLICT(id_almacen,id_producto) DO UPDATE SET stock_minimo=EXCLUDED.stock_minimo,id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP;
 END IF;
 -- Con saldo cero también se conserva el costo por unidad indicado al crear.
 -- No genera existencias ni movimientos; la primera entrada recalculará el promedio.
 IF n=0 AND pr.controla_stock AND pr.id_almacen_stock IS NOT NULL THEN
  UPDATE alm_producto_stock SET costo_promedio=costo,
   id_usuario_modificacion=p_usuario,fecha_modificacion=CURRENT_TIMESTAMP
  WHERE id_producto=pr.id AND id_almacen=pr.id_almacen_stock;
 END IF;
 IF n>0 THEN
  PERFORM alm_aplicar('INICIAL-'||pr.id,'ENTRADA','SALDO_INICIAL','PRODUCTO',pr.id,
   jsonb_build_array(jsonb_build_object('id_producto',pr.id,'id_almacen',pr.id_almacen_stock,'id_unidad_medida',pr.id_unidad_medida,
    'cantidad',n,'signo',1,'costo_unitario',costo)),p_usuario);
 END IF;
 RETURN pro_obtener_producto(pr.id);
END $$;

CREATE OR REPLACE FUNCTION pro_obtener_receta(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            r.id,
            r.id_producto,
            p.nombre AS nombre_producto,
            r.version,
            r.nombre AS nombre_receta,
            r.rendimiento_porciones,
            r.vigente,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            -- Costo de la receta completa. Con rendimiento_porciones = 1 es el
            -- costo del plato; pro_costo_unitario_insumo lo resuelve igual que el
            -- cálculo guardado, así que el detalle de abajo suma este mismo valor.
            p.costo_receta_calculado AS costo_total_calculado,
            (
                SELECT COALESCE(json_agg(row_to_json(ri_t)), '[]'::JSON)
                FROM (
                    SELECT
                        ri.id,
                        ri.id_receta,
                        ri.id_producto_insumo,
                        pi.nombre AS nombre_insumo,
                        pi.tipo_producto,
                        ri.cantidad,
                        ri.id_unidad_medida,
                        um.simbolo AS simbolo_unidad,
                        ri.porcentaje_merma,
                        ri.es_opcional,
                        ri.grupo_sustitucion,
                        ri.orden,
                        pro_costo_unitario_insumo(ri.id_producto_insumo) AS costo_unitario_estimado,
                        round(
                            ri.cantidad * (1 + ri.porcentaje_merma / 100.0)
                            * pro_costo_unitario_insumo(ri.id_producto_insumo),
                            4
                        ) AS monto_subtotal
                    FROM pro_receta_insumo ri
                    INNER JOIN pro_producto pi ON ri.id_producto_insumo = pi.id
                    INNER JOIN pro_unidad_medida um ON ri.id_unidad_medida = um.id
                    WHERE ri.id_receta = r.id AND ri.estado = 1
                    ORDER BY ri.orden ASC, ri.id ASC
                ) ri_t
            ) AS insumos
        FROM pro_receta r
        INNER JOIN pro_producto p ON r.id_producto = p.id
        WHERE r.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS pro_recalcular_costo_receta(BIGINT);
DROP FUNCTION IF EXISTS pro_recalcular_costo_receta(BIGINT, INTEGER);

CREATE OR REPLACE FUNCTION pro_recalcular_costo_receta(p_id_receta BIGINT, p_profundidad INTEGER DEFAULT 0)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_producto BIGINT;
    v_costo_total NUMERIC(12, 4);
    v_padres BIGINT[];
    v_padre BIGINT;
BEGIN
    -- Red de seguridad ante un ciclo introducido por escrito directo en la base,
    -- saltándose pro_guardar_receta_insumo. Sin esto la cascada no terminaría.
    IF p_profundidad >= 20 THEN
        RETURN;
    END IF;

    SELECT id_producto INTO v_id_producto
    FROM pro_receta
    WHERE id = p_id_receta AND estado = 1;

    IF v_id_producto IS NULL THEN
        RETURN;
    END IF;

    -- El costo de cada insumo lo resuelve pro_costo_unitario_insumo, la misma
    -- función que usa pro_obtener_receta: así el detalle por insumo que ve el
    -- usuario suma exactamente este total.
    SELECT COALESCE(SUM(
        ri.cantidad * (1 + (ri.porcentaje_merma / 100.0))
        * pro_costo_unitario_insumo(ri.id_producto_insumo)
    ), 0)
    INTO v_costo_total
    FROM pro_receta_insumo ri
    WHERE ri.id_receta = p_id_receta AND ri.estado = 1;

    UPDATE pro_producto
    SET costo_receta_calculado = v_costo_total,
        fecha_modificacion = NOW()
    WHERE id = v_id_producto;

    -- Propaga hacia arriba a las recetas que contienen este producto.
    SELECT COALESCE(array_agg(DISTINCT ri.id_receta), ARRAY[]::BIGINT[])
    INTO v_padres
    FROM pro_receta_insumo ri
    JOIN pro_receta r ON r.id = ri.id_receta
    WHERE ri.id_producto_insumo = v_id_producto
      AND ri.estado = 1
      AND r.estado = 1
      AND ri.id_receta <> p_id_receta;

    FOREACH v_padre IN ARRAY v_padres LOOP
        PERFORM pro_recalcular_costo_receta(v_padre, p_profundidad + 1);
    END LOOP;
END;
$function$;
DO $$
DECLARE
    v_receta RECORD;
    v_total INTEGER := 0;
BEGIN
    FOR v_receta IN
        SELECT r.id
        FROM pro_receta r
        WHERE r.estado = 1 AND r.vigente
    LOOP
        PERFORM pro_recalcular_costo_receta(v_receta.id);
        v_total := v_total + 1;
    END LOOP;

    RAISE NOTICE 'Recetas recalculadas: %', v_total;
END;
$$;
COMMIT;

