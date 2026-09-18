-- Registro un pago de planilla.
--
-- La quincena la DEDUZCO de la fecha de pago en vez de pedirla, y es la
-- decisión más importante de esta función. Inga paga el día 17 la primera
-- quincena y el día 2 del mes siguiente la segunda. Si el cajero tuviera que
-- elegir el período a mano, el 2 de octubre marcaría "octubre" cuando en
-- realidad está pagando la segunda quincena de septiembre — y el gasto
-- quedaría en el mes equivocado, desviando la rentabilidad de los dos meses.
--
-- Regla que aplico:
--   pago entre el día 1 y el 15  → segunda quincena del MES ANTERIOR
--   pago del día 16 en adelante  → primera quincena del MES EN CURSO
--
-- El período se puede forzar (p_anio/p_mes/p_quincena) para cargar pagos
-- atrasados o corregir un registro histórico.
CREATE OR REPLACE FUNCTION pla_registrar_pago(
    p_id_trabajador BIGINT,
    p_monto NUMERIC,
    p_fecha_pago DATE DEFAULT NULL,
    p_medio_pago SMALLINT DEFAULT 1,
    p_id_turno BIGINT DEFAULT NULL,
    p_anio INTEGER DEFAULT NULL,
    p_mes INTEGER DEFAULT NULL,
    p_quincena INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
    v_anio INTEGER;
    v_mes INTEGER;
    v_quincena INTEGER;
    v_referencia DATE;
    v_estado_turno SMALLINT;
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_pago, CURRENT_DATE);

    SELECT TRIM(nombres || ' ' || apellidos) INTO v_nombre
    FROM pla_trabajador WHERE id = p_id_trabajador AND estado = 1;

    IF v_nombre IS NULL THEN
        RETURN json_build_object('error', 'El trabajador no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto del pago debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF COALESCE(p_medio_pago, 1) NOT IN (1, 2, 3) THEN
        RETURN json_build_object(
            'error', 'El medio de pago debe ser efectivo, Yape o tarjeta/transferencia',
            'registro', NULL
        );
    END IF;

    -- No permito registrar un pago con fecha futura: el gasto entra al cuadre
    -- del día y adelantarlo descuadraría la caja de una fecha que no ha pasado.
    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede registrar un pago con fecha futura', 'registro', NULL);
    END IF;

    -- Deducción del período, salvo que venga forzado.
    IF p_anio IS NOT NULL AND p_mes IS NOT NULL AND p_quincena IS NOT NULL THEN
        v_anio := p_anio;
        v_mes := p_mes;
        v_quincena := p_quincena;
    ELSE
        IF EXTRACT(DAY FROM v_fecha) <= 15 THEN
            -- Pago de la primera mitad del mes: corresponde a la 2da quincena
            -- del mes anterior.
            v_referencia := (v_fecha - INTERVAL '1 month')::DATE;
            v_quincena := 2;
        ELSE
            v_referencia := v_fecha;
            v_quincena := 1;
        END IF;
        v_anio := EXTRACT(YEAR FROM v_referencia)::INTEGER;
        v_mes := EXTRACT(MONTH FROM v_referencia)::INTEGER;
    END IF;

    IF v_mes NOT BETWEEN 1 AND 12 THEN
        RETURN json_build_object('error', 'El mes del período debe estar entre 1 y 12', 'registro', NULL);
    END IF;

    IF v_quincena NOT IN (1, 2) THEN
        RETURN json_build_object('error', 'La quincena debe ser 1 o 2', 'registro', NULL);
    END IF;

    -- El índice uq_pla_pago_quincena ya lo impide, pero valido acá para dar un
    -- mensaje que diga de qué período se trata.
    IF EXISTS (
        SELECT 1 FROM pla_pago
        WHERE id_trabajador = p_id_trabajador
          AND anio = v_anio AND mes = v_mes AND quincena = v_quincena
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', v_nombre || ' ya tiene registrado el pago de la quincena ' ||
                     v_quincena || ' de ' || v_mes || '/' || v_anio ||
                     '. Anula el anterior si necesitas corregirlo.',
            'registro', NULL
        );
    END IF;

    -- Si el pago sale del cajón (efectivo), exijo un turno abierto: así el
    -- egreso queda amarrado al cuadre del día, que es el objetivo del módulo.
    IF COALESCE(p_medio_pago, 1) = 1 THEN
        IF p_id_turno IS NULL THEN
            RETURN json_build_object(
                'error', 'Un pago en efectivo debe registrarse contra un turno de caja abierto',
                'registro', NULL
            );
        END IF;

        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = p_id_turno AND estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El turno de caja indicado no existe', 'registro', NULL);
        END IF;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'error', 'No se puede registrar el pago: el turno de caja ya está cerrado',
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO pla_pago (
        id_trabajador, id_turno, fecha_pago, anio, mes, quincena,
        monto, medio_pago, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_trabajador,
        p_id_turno,
        v_fecha,
        v_anio, v_mes, v_quincena,
        p_monto,
        COALESCE(p_medio_pago, 1),
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pla_obtener_pago(v_id);
END;
$function$;
