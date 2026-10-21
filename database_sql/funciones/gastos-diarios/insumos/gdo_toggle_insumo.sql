-- Doy de baja o reactivo un insumo de la lista maestra. La baja no se bloquea aunque tenga compras.
DROP FUNCTION IF EXISTS gdo_toggle_insumo(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gdo_toggle_insumo(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nuevo_estado SMALLINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT CASE WHEN estado = 1 THEN 0 ELSE 1 END
    INTO v_nuevo_estado
    FROM gdo_insumo WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE gdo_insumo
    SET estado = v_nuevo_estado,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id;

    RETURN json_build_object(
        'eliminado', TRUE,
        'id', p_id,
        'estado', v_nuevo_estado
    );
END;
$function$;
