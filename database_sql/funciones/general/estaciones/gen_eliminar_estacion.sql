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

    -- La marca de caja principal puede no existir en instalaciones antiguas.
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

    -- Una estación con tickets sin terminar no debe desaparecer de la cola:
    -- al desactivarla, esos trabajos quedarían atascados para siempre.
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