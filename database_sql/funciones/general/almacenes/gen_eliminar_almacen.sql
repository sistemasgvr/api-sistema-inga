DROP FUNCTION IF EXISTS gen_eliminar_almacen(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT
);
DROP FUNCTION IF EXISTS gen_eliminar_almacen(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION gen_eliminar_almacen(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_sucursal IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id AND id_sucursal = p_id_sucursal
    ) THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF EXISTS (
        SELECT 1 FROM alm_producto_stock
        WHERE id_almacen = p_id AND stock_actual > 0
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede dar de baja el almacén porque cuenta con stock actual en productos'
        );
    END IF;

    UPDATE gen_almacen
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1
      AND (p_id_sucursal IS NULL OR id_sucursal = p_id_sucursal);

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;