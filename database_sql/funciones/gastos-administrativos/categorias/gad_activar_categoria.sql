-- Reactivo una categoría de gasto dada de baja.
--
-- Si es una subcategoría, reviso que su padre siga activo: reactivarla bajo una
-- rama dada de baja la dejaría invisible en el árbol, sin que nadie entienda
-- por qué no aparece.
CREATE OR REPLACE FUNCTION gad_activar_categoria(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_padre BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_categoria_padre INTO v_padre
    FROM gad_categoria
    WHERE id = p_id AND estado = 0;

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    IF v_padre IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gad_categoria WHERE id = v_padre AND estado = 1
    ) THEN
        RETURN json_build_object(
            'activado', FALSE,
            'id', p_id,
            'error', 'No se puede reactivar: su categoría padre está dada de baja. Reactívala primero.'
        );
    END IF;

    UPDATE gad_categoria
    SET estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 0;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;
