-- Guardo el conteo de billetes y monedas de un turno.
--
-- Recibo el arqueo completo como un JSON de pares {denominacion, cantidad} y
-- REEMPLAZO todo lo que hubiera antes, en vez de ir insertando fila por fila.
--
-- Lo hago así porque el cajero cuenta, se equivoca, recuenta y vuelve a guardar
-- varias veces antes de cerrar. Si fuera acumulativo, cada recuento sumaría
-- sobre el anterior y el total saldría inflado. Reemplazar deja el arqueo
-- siempre igual a lo último que contó, que es lo que él espera.
--
-- El monto_subtotal lo calculo yo (denominación × cantidad) y no lo acepto del
-- front: es una multiplicación, no un dato de entrada.
CREATE OR REPLACE FUNCTION caj_guardar_arqueo(
    p_id_turno BIGINT,
    p_detalle JSON,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_turno SMALLINT;
    v_item JSON;
    v_denominacion NUMERIC(12,2);
    v_cantidad INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado_turno INTO v_estado_turno
    FROM caj_turno WHERE id = p_id_turno AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El turno no existe o fue anulado', 'registro', NULL);
    END IF;

    IF v_estado_turno = 2 THEN
        RETURN json_build_object(
            'error', 'No se puede modificar el arqueo de un turno cerrado',
            'registro', NULL
        );
    END IF;

    IF p_detalle IS NULL OR json_array_length(p_detalle) = 0 THEN
        RETURN json_build_object('error', 'Debes enviar al menos una denominación', 'registro', NULL);
    END IF;

    -- Valido todo antes de borrar nada. Si una línea viene mal, salgo sin
    -- haber tocado el arqueo anterior: prefiero que conserve su conteo previo
    -- antes que dejarlo a medias.
    FOR v_item IN SELECT * FROM json_array_elements(p_detalle)
    LOOP
        v_denominacion := (v_item->>'denominacion')::NUMERIC;
        v_cantidad := (v_item->>'cantidad')::INTEGER;

        IF v_denominacion IS NULL OR v_denominacion <= 0 THEN
            RETURN json_build_object('error', 'Hay una denominación inválida en el arqueo', 'registro', NULL);
        END IF;

        IF v_cantidad IS NULL OR v_cantidad < 0 THEN
            RETURN json_build_object(
                'error', 'La cantidad de billetes o monedas no puede ser negativa',
                'registro', NULL
            );
        END IF;
    END LOOP;

    DELETE FROM caj_arqueo_detalle WHERE id_turno = p_id_turno;

    INSERT INTO caj_arqueo_detalle (
        id_turno, denominacion, cantidad, monto_subtotal,
        id_usuario_creacion, id_usuario_modificacion
    )
    SELECT
        p_id_turno,
        (item->>'denominacion')::NUMERIC,
        (item->>'cantidad')::INTEGER,
        (item->>'denominacion')::NUMERIC * (item->>'cantidad')::INTEGER,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    FROM json_array_elements(p_detalle) AS item
    -- Ignoro las denominaciones en cero: no aportan nada y solo ensucian
    -- el detalle que se ve al revisar el cierre.
    WHERE (item->>'cantidad')::INTEGER > 0;

    RETURN caj_resumen_turno(p_id_turno);
END;
$function$;
