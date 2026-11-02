-- Devuelve el turno abierto de un cajero, o NULL si no tiene ninguno.
DROP FUNCTION IF EXISTS caj_obtener_turno_abierto(p_id_cajero BIGINT);
DROP FUNCTION IF EXISTS caj_obtener_turno_abierto(p_id_cajero BIGINT, p_id_sucursal BIGINT);
CREATE OR REPLACE FUNCTION caj_obtener_turno_abierto(p_id_cajero BIGINT, p_id_sucursal BIGINT DEFAULT NULL)
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
      AND caj_turno_de_sucursal(id, p_id_sucursal)
    LIMIT 1;

    IF v_id IS NULL THEN
        -- Devuelvo la misma forma que las demás funciones ('registro': null)
        -- para que la capa de Nest no tenga que tratar este caso distinto.
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN caj_obtener_turno(v_id);
END;
$function$;
