-- Devuelve el turno de caja contra el que se registran cobros, pagos y gastos,
-- o NULL si no hay ninguna caja abierta.
DROP FUNCTION IF EXISTS caj_obtener_turno_vigente(
    p_id_usuario BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION caj_obtener_turno_vigente(
    p_id_usuario BIGINT,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT t.id INTO v_id
    FROM caj_turno t
    JOIN caj_caja c ON c.id = t.id_caja
    WHERE t.estado = 1
      AND t.estado_turno = 1
      AND c.estado = 1
      AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
    ORDER BY (t.id_cajero = p_id_usuario) DESC, t.id DESC
    LIMIT 1;

    IF v_id IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN caj_obtener_turno(v_id);
END;
$function$;
