CREATE OR REPLACE FUNCTION pro_eliminar_receta_insumo(
    p_id_insumo_receta BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_receta BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_receta INTO v_id_receta
    FROM pro_receta_insumo
    WHERE id = p_id_insumo_receta;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'error', 'El ítem de insumo en la receta no existe');
    END IF;

    UPDATE pro_receta_insumo
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_insumo_receta AND estado = 1;

    RETURN pro_obtener_receta(v_id_receta);
END;
$function$;
