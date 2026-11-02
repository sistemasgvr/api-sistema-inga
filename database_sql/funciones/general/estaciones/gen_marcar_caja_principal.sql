-- Marca la estación principal de caja de su sucursal. Los tickets de precuenta o
-- comprobante que aún no salieron pasan a la nueva estación para no quedar
-- atascados. Con p_id_sucursal (la de la sesión) la estación debe ser de esa sucursal.
DROP FUNCTION IF EXISTS gen_marcar_caja_principal(p_id BIGINT);
DROP FUNCTION IF EXISTS gen_marcar_caja_principal(p_id BIGINT, p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION gen_marcar_caja_principal(
    p_id BIGINT,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_sucursal BIGINT;
    v_nombre VARCHAR;
BEGIN
    SELECT id_sucursal, nombre
    INTO v_sucursal, v_nombre
    FROM gen_estacion
    WHERE id = p_id
      AND estado = 1
      AND (p_id_sucursal IS NULL OR id_sucursal = p_id_sucursal);

    IF v_sucursal IS NULL THEN
        RAISE EXCEPTION 'Estación inactiva o inexistente';
    END IF;

    PERFORM 1 FROM gen_sucursal WHERE id = v_sucursal FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1
        FROM gen_estacion
        WHERE id = p_id
          AND NULLIF(TRIM(impresora_ip), '') IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Configure la impresora de la estación de caja';
    END IF;

    UPDATE gen_estacion
    SET es_caja_principal = FALSE
    WHERE id_sucursal = v_sucursal
      AND es_caja_principal;

    UPDATE gen_estacion
    SET es_caja_principal = TRUE
    WHERE id = p_id;

    IF to_regclass('public.ven_impresion_trabajo') IS NOT NULL THEN
        UPDATE ven_impresion_trabajo t
        SET id_estacion = p_id,
            contenido = jsonb_set(t.contenido, '{estacion}', to_jsonb(v_nombre)),
            actualizado = CURRENT_TIMESTAMP
        FROM ven_comanda c
        JOIN ven_pedido p ON p.id = c.id_pedido
        WHERE c.id = t.id_comanda
          AND t.estado = 'pendiente'
          AND p.id_sucursal = v_sucursal
          AND t.id_estacion <> p_id
          AND t.contenido->>'tipo' IN ('PRECUENTA', 'COMPROBANTE');
    END IF;

    RETURN gen_obtener_estacion(p_id);
END;
$function$;
