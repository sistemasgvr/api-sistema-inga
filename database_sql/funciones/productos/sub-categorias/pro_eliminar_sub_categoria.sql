DROP FUNCTION IF EXISTS pro_eliminar_sub_categoria(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pro_eliminar_sub_categoria(
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
        SELECT 1 FROM pro_producto
        WHERE id_subcategoria = p_id AND estado = 1
          AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa)
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar la subcategoría porque tiene productos activos'
        );
    END IF;

    UPDATE pro_subcategoria
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1
      AND (p_id_empresa IS NULL OR id_empresa = p_id_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;