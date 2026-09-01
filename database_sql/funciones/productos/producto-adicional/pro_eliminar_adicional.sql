CREATE OR REPLACE FUNCTION pro_eliminar_adicional(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pro_adicional
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'error', 'El adicional no existe o ya está inactivo');
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;