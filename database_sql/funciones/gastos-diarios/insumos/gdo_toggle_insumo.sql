DROP FUNCTION IF EXISTS gdo_toggle_insumo(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION gdo_toggle_insumo(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nuevo_estado SMALLINT;
    v_empresa BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_empresa := COALESCE(p_id_empresa, (SELECT id_empresa FROM gdo_insumo WHERE id = p_id));

    SELECT CASE WHEN estado = 1 THEN 0 ELSE 1 END
    INTO v_nuevo_estado
    FROM gdo_insumo WHERE id = p_id
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE gdo_insumo
    SET estado = v_nuevo_estado,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    RETURN json_build_object(
        'eliminado', TRUE,
        'id', p_id,
        'estado', v_nuevo_estado
    );
END;
$function$;