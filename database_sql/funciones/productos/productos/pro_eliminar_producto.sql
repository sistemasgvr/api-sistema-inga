DROP FUNCTION IF EXISTS pro_eliminar_producto(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pro_eliminar_producto(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM alm_producto_stock
        WHERE id_producto = p_id AND estado = 1 AND stock_actual <> 0
          AND (p_id_empresa IS NULL OR id_almacen IN (SELECT id FROM gen_almacen WHERE id_empresa = p_id_empresa))
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el producto porque aún conserva stock registrado en almacén'
        );
    END IF;

    UPDATE pro_producto
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1
      AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;