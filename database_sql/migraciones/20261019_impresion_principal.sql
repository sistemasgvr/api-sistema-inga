BEGIN;

-- Al cambiar la estación principal de caja, los tickets de precuenta o
-- comprobante que aún no salieron deben seguir a la nueva estación. Si no,
-- quedan atascados en la estación anterior o en una estación desactivada.
CREATE OR REPLACE FUNCTION gen_marcar_caja_principal(p_id BIGINT) RETURNS JSON
LANGUAGE plpgsql AS $$
DECLARE
  suc BIGINT;
  v_nombre VARCHAR;
BEGIN
  SELECT id_sucursal, nombre INTO suc, v_nombre
  FROM gen_estacion WHERE id = p_id AND estado = 1;

  IF suc IS NULL THEN RAISE EXCEPTION 'Estación inactiva o inexistente'; END IF;
  PERFORM 1 FROM gen_sucursal WHERE id = suc FOR UPDATE;

  IF NOT EXISTS (
    SELECT 1 FROM gen_estacion
    WHERE id = p_id AND NULLIF(trim(impresora_ip), '') IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Configure la impresora de la estación de caja';
  END IF;

  UPDATE gen_estacion SET es_caja_principal = FALSE
  WHERE id_sucursal = suc AND es_caja_principal;

  UPDATE gen_estacion SET es_caja_principal = TRUE WHERE id = p_id;

  IF to_regclass('public.ven_impresion_trabajo') IS NOT NULL THEN
    UPDATE ven_impresion_trabajo t
    SET id_estacion = p_id,
        contenido = jsonb_set(t.contenido, '{estacion}', to_jsonb(v_nombre)),
        actualizado = CURRENT_TIMESTAMP
    FROM ven_comanda c
    JOIN ven_pedido p ON p.id = c.id_pedido
    WHERE c.id = t.id_comanda
      AND t.estado = 'pendiente'
      AND p.id_sucursal = suc
      AND t.id_estacion <> p_id
      AND t.contenido->>'tipo' IN ('PRECUENTA', 'COMPROBANTE');
  END IF;

  RETURN gen_obtener_estacion(p_id);
END $$;

-- Evita dejar la sucursal sin estación principal o perder trabajos de
-- impresión al desactivar una estación.
CREATE OR REPLACE FUNCTION gen_eliminar_estacion(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM pro_producto
        WHERE id_estacion = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede dar de baja la estación porque tiene productos activos asociados'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'gen_estacion'
          AND column_name = 'es_caja_principal'
    ) THEN
        IF EXISTS (
            SELECT 1 FROM gen_estacion
            WHERE id = p_id AND estado = 1 AND es_caja_principal
        ) THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id,
                'error', 'No se puede desactivar la estación principal de caja. Marca otra estación como principal y vuelve a intentarlo'
            );
        END IF;
    END IF;

    IF to_regclass('public.ven_impresion_trabajo') IS NOT NULL AND EXISTS (
        SELECT 1 FROM ven_impresion_trabajo
        WHERE id_estacion = p_id
          AND estado IN ('pendiente', 'procesando', 'revision')
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'La estación tiene comandas o comprobantes pendientes de impresión. Resuélvelos en la cola antes de desactivarla'
        );
    END IF;

    UPDATE gen_estacion
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;

COMMIT;
