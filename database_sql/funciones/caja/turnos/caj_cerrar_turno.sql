-- Cierro un turno de caja.
--
-- Acá se congela el resultado del turno. Guardo tres números:
--   monto_cierre_sistema    → lo que el sistema dice que debería haber
--   monto_cierre_declarado  → lo que el cajero contó de verdad
--   monto_diferencia        → sistema − declarado
--
-- El orden de la resta lo tomo del resumen funcional del proyecto
-- (resumen_sistema_inga.md, M11): "monto_diferencia = sistema − declarado".
-- Con esa convención:
--   positiva = FALTANTE (el sistema esperaba más de lo que hay en el cajón)
--   negativa = SOBRANTE (hay más plata de la que debería)
--
-- Lo dejo escrito porque es contraintuitivo: en contabilidad lo habitual es
-- "real − esperado", donde positivo sería sobrante. Acá es al revés a propósito.
-- Si guardara el valor absoluto perdería la distinción, que es justo la que le
-- importa al administrador cuando revisa los cierres.
--
-- Calculo monto_cierre_sistema en el momento del cierre y no lo tomo de lo que
-- mande el front: es un dato que no debe poder manipularse desde afuera.
CREATE OR REPLACE FUNCTION caj_cerrar_turno(
    p_id BIGINT,
    p_monto_cierre_declarado NUMERIC,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_turno SMALLINT;
    v_totales JSONB;
    v_esperado NUMERIC(12,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado_turno INTO v_estado_turno
    FROM caj_turno WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El turno no existe o fue anulado', 'registro', NULL);
    END IF;

    IF v_estado_turno = 2 THEN
        RETURN json_build_object('error', 'Este turno ya fue cerrado', 'registro', NULL);
    END IF;

    IF p_monto_cierre_declarado IS NULL THEN
        RETURN json_build_object(
            'error', 'Debes indicar cuánto efectivo contaste al cerrar',
            'registro', NULL
        );
    END IF;

    IF p_monto_cierre_declarado < 0 THEN
        RETURN json_build_object('error', 'El monto declarado no puede ser negativo', 'registro', NULL);
    END IF;

    v_totales := caj_calcular_totales_turno(p_id)::JSONB;
    v_esperado := (v_totales->>'efectivo_esperado')::NUMERIC;

    UPDATE caj_turno
    SET
        monto_cierre_sistema = v_esperado,
        monto_cierre_declarado = p_monto_cierre_declarado,
        monto_diferencia = v_esperado - p_monto_cierre_declarado,
        fecha_cierre = NOW(),
        estado_turno = 2, -- TURNO_ESTADO: 2 = CERRADO
        -- Concateno la observación de cierre con la de apertura en vez de
        -- pisarla: las dos son parte de la historia del turno.
        observacion = TRIM(BOTH ' ' FROM
            COALESCE(observacion || ' | ', '') || COALESCE(NULLIF(TRIM(p_observacion), ''), '')
        ),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id;

    RETURN caj_obtener_turno(p_id);
END;
$function$;
