-- Reporte del día: el cuadre que hoy hacen a mano en el Excel de egresos.
--
-- Es el ítem del alcance: "al cierre del día, mostrar el desglose: cuánto se
-- gastó en efectivo, cuánto en Yape y cuánto quedó a crédito".
--
-- Devuelvo tres cortes del mismo día:
--   1. Los totales por forma de pago (el cuadre propiamente dicho).
--   2. El desglose por categoría, para saber en qué se fue la plata.
--   3. El desglose por proveedor de las compras a crédito, que es lo que se
--      va a abonar esta semana en CxP.
--
-- Si no se indica fecha, uso hoy.
CREATE OR REPLACE FUNCTION gdo_reporte_dia(
    p_fecha_gasto DATE DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_dia BIGINT;
    v_efectivo NUMERIC(12,2);
    v_yape NUMERIC(12,2);
    v_credito NUMERIC(12,2);
    v_cantidad BIGINT;
    v_por_categoria JSON;
    v_por_proveedor JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_gasto, CURRENT_DATE);

    SELECT id INTO v_id_dia
    FROM gdo_gasto_dia
    WHERE fecha_gasto = v_fecha
      AND COALESCE(id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
      AND estado = 1;

    -- Si no hubo gasto ese día, devuelvo el reporte en cero. No es un error:
    -- un día sin compras es una respuesta válida.
    IF v_id_dia IS NULL THEN
        RETURN json_build_object(
            'registro', json_build_object(
                'fecha_gasto', v_fecha,
                'id_gasto_dia', NULL,
                'total_efectivo', 0,
                'total_yape', 0,
                'total_credito', 0,
                'total_general', 0,
                'cantidad_items', 0,
                'por_categoria', '[]'::JSON,
                'por_proveedor', '[]'::JSON
            )
        );
    END IF;

    SELECT
        COALESCE(SUM(det.subtotal) FILTER (WHERE det.forma_pago = 1), 0),
        COALESCE(SUM(det.subtotal) FILTER (WHERE det.forma_pago = 2), 0),
        COALESCE(SUM(det.subtotal) FILTER (WHERE det.forma_pago = 3), 0),
        COUNT(*)
    INTO v_efectivo, v_yape, v_credito, v_cantidad
    FROM gdo_gasto_detalle det
    WHERE det.id_gasto_dia = v_id_dia AND det.estado = 1;

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.monto DESC), '[]'::JSON)
    INTO v_por_categoria
    FROM (
        SELECT
            cat.id AS id_categoria,
            cat.nombre AS nombre_categoria,
            SUM(det.subtotal) AS monto,
            COUNT(*) AS cantidad
        FROM gdo_gasto_detalle det
        INNER JOIN gdo_insumo i ON det.id_insumo = i.id
        INNER JOIN gdo_categoria cat ON i.id_categoria = cat.id
        WHERE det.id_gasto_dia = v_id_dia AND det.estado = 1
        GROUP BY cat.id, cat.nombre
    ) x;

    -- Solo las compras a crédito: es lo que suma deuda y se abona después.
    SELECT COALESCE(json_agg(row_to_json(y) ORDER BY y.monto DESC), '[]'::JSON)
    INTO v_por_proveedor
    FROM (
        SELECT
            p.id AS id_persona,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) AS nombre_proveedor,
            SUM(det.subtotal) AS monto,
            COUNT(*) AS cantidad
        FROM gdo_gasto_detalle det
        INNER JOIN cli_persona p ON det.id_proveedor = p.id
        WHERE det.id_gasto_dia = v_id_dia
          AND det.estado = 1
          AND det.forma_pago = 3
        GROUP BY p.id, p.nombres, p.apellido_paterno, p.razon_social
    ) y;

    RETURN json_build_object(
        'registro', json_build_object(
            'fecha_gasto', v_fecha,
            'id_gasto_dia', v_id_dia,
            'total_efectivo', v_efectivo,
            'total_yape', v_yape,
            'total_credito', v_credito,
            'total_general', v_efectivo + v_yape + v_credito,
            'cantidad_items', v_cantidad,
            'por_categoria', v_por_categoria,
            'por_proveedor', v_por_proveedor
        )
    );
END;
$function$;
