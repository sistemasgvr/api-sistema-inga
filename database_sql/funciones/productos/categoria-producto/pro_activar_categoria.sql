CREATE OR REPLACE FUNCTION pro_activar_categoria(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado
    FROM pro_categoria
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La categoría con ID % no existe', p_id;
    END IF;

    IF v_estado = 1 THEN
        -- Opcional: podrías permitirlo o retornar un mensaje amigable sin romper con 404
        RAISE EXCEPTION 'La categoría ya se encuentra activa';
    END IF;

    UPDATE pro_categoria
    SET estado = 1,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('exito', TRUE, 'id', p_id);
END;
$function$;