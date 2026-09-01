CREATE OR REPLACE FUNCTION pro_eliminar_receta(
    p_id_receta BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pro_receta
    SET estado = 0,
        vigente = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_receta AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'error', 'La receta no existe o ya está inactiva');
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_receta);
END;
$function$;