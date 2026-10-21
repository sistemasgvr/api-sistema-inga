-- Doy de baja lógica un trabajador (estado = 0). No se bloquea por tener pagos;
-- solo avisa si ya tiene un pago registrado este mes.
DROP FUNCTION IF EXISTS pla_eliminar_trabajador(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION pla_eliminar_trabajador(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pla_trabajador
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE auth_sesion SET estado = 0
    WHERE id_usuario IN (SELECT id FROM auth_usuario WHERE id_trabajador = p_id)
      AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
