-- Devuelve el turno abierto de un cajero, o NULL si no tiene ninguno.
--
-- Esta es la primera llamada que hace la pantalla de caja al cargar: necesita
-- saber si el cajero ya tiene un turno en curso para mostrarle el panel del
-- turno, o la pantalla de apertura si no lo tiene.
--
-- La va a usar también el cobro (M12): antes de registrar un pago hay que saber
-- contra qué turno se registra, y ese dato sale de acá.
CREATE OR REPLACE FUNCTION caj_obtener_turno_abierto(p_id_cajero BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id INTO v_id
    FROM caj_turno
    WHERE id_cajero = p_id_cajero AND estado_turno = 1 AND estado = 1
    LIMIT 1;

    IF v_id IS NULL THEN
        -- Devuelvo la misma forma que las demás funciones ('registro': null)
        -- para que la capa de Nest no tenga que tratar este caso distinto.
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN caj_obtener_turno(v_id);
END;
$function$;
