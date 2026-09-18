-- Doy de baja lógica una caja.
--
-- Bloqueo la baja si tiene un turno abierto. Si la dejara pasar, ese turno
-- quedaría huérfano: nadie podría cerrarlo desde la pantalla porque la caja ya
-- no aparecería en el listado, y el dinero del cajón quedaría sin cuadrar.
CREATE OR REPLACE FUNCTION caj_eliminar_caja(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM caj_turno
        WHERE id_caja = p_id AND estado_turno = 1 AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede dar de baja la caja porque tiene un turno abierto. Ciérralo primero.'
        );
    END IF;

    UPDATE caj_caja
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
