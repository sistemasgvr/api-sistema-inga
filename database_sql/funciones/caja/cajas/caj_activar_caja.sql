-- Reactivo una caja dada de baja.
DROP FUNCTION IF EXISTS caj_activar_caja(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT
);
DROP FUNCTION IF EXISTS caj_activar_caja(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION caj_activar_caja(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE caj_caja
    SET estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 0
      AND (p_id_sucursal IS NULL OR id_sucursal = p_id_sucursal);

    IF NOT FOUND THEN
        RETURN json_build_object('activado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('activado', TRUE, 'id', p_id);
END;
$function$;
