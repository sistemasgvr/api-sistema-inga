CREATE OR REPLACE FUNCTION pro_eliminar_receta_insumo(
    p_id_receta_insumo BIGINT,
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
    WHERE id = p_id_receta_insumo AND estado = 1;

    IF v_id_receta IS NULL THEN
        RETURN json_build_object('error', 'El insumo de receta no existe o ya está inactivo', 'registro', NULL);
    END IF;

    UPDATE pro_receta_insumo
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_receta_insumo;

    PERFORM pro_recalcular_costo_receta(v_id_receta);

    RETURN pro_obtener_receta(v_id_receta);
END;
$function$;