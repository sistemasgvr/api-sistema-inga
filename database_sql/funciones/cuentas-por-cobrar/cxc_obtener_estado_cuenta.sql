-- Estado de cuenta de una persona: sus datos, su saldo y su historial completo.
--
-- Es lo que se imprime o se le muestra al trabajador del consorcio cuando
-- pregunta "¿cuánto debo?". Por eso devuelvo todo junto en una sola llamada: la
-- pantalla no debería tener que pegar tres respuestas para armar un papel.
--
-- El historial va del más viejo al más nuevo, al revés que el listado general.
-- Un estado de cuenta se lee como una cartilla: empieza en cero y va sumando, y
-- así la columna saldo_resultante se sigue con el dedo hacia abajo.
--
-- Acepta un periodo opcional. Sin periodo trae todo; con periodo trae la
-- quincena que se está conciliando, más el saldo anterior para que el papel
-- cuadre.
CREATE OR REPLACE FUNCTION cxc_obtener_estado_cuenta(
    p_id_persona BIGINT,
    p_anio SMALLINT DEFAULT NULL,
    p_mes SMALLINT DEFAULT NULL,
    p_quincena SMALLINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_persona JSON;
    v_movimientos JSON;
    v_saldo NUMERIC(12,2);
    v_saldo_anterior NUMERIC(12,2);
    v_cargos NUMERIC(12,2);
    v_abonos NUMERIC(12,2);
    v_existe BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT TRUE INTO v_existe FROM cli_persona WHERE id = p_id_persona AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La persona no existe o está inactiva', 'registro', NULL);
    END IF;

    SELECT row_to_json(x) INTO v_persona
    FROM (
        SELECT
            v.id_persona,
            v.nombre,
            v.num_documento,
            v.id_convenio,
            v.convenio,
            v.limite_credito,
            v.saldo,
            (COALESCE(v.limite_credito, 0) > 0 AND v.saldo > v.limite_credito) AS supera_limite,
            CASE
                WHEN COALESCE(v.limite_credito, 0) > 0 THEN v.limite_credito - v.saldo
                ELSE NULL
            END AS credito_disponible
        FROM vw_cxc_saldo_persona v
        WHERE v.id_persona = p_id_persona
    ) x;

    IF v_persona IS NULL THEN
        RETURN json_build_object(
            'error', 'La persona no está marcada como cliente, así que no tiene cuenta corriente',
            'registro', NULL
        );
    END IF;

    v_saldo := cxc_calcular_saldo_persona(p_id_persona);

    -- Saldo anterior al periodo pedido. Sin periodo, arranca en cero porque el
    -- historial trae todo desde el principio.
    IF p_anio IS NULL THEN
        v_saldo_anterior := 0;
    ELSE
        SELECT COALESCE(SUM(
            CASE
                WHEN m.tipo_movimiento = 1 THEN m.monto
                WHEN m.tipo_movimiento = 2 THEN -m.monto
                ELSE m.monto
            END
        ), 0)
        INTO v_saldo_anterior
        FROM cxc_movimiento m
        WHERE m.id_persona = p_id_persona
          AND m.estado = 1
          AND (m.anio, m.mes, m.quincena) <
              (p_anio, COALESCE(p_mes, 1)::SMALLINT, COALESCE(p_quincena, 1)::SMALLINT);
    END IF;

    SELECT
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0)
    INTO v_cargos, v_abonos
    FROM cxc_movimiento m
    WHERE m.id_persona = p_id_persona
      AND m.estado = 1
      AND (p_anio IS NULL OR m.anio = p_anio)
      AND (p_mes IS NULL OR m.mes = p_mes)
      AND (p_quincena IS NULL OR m.quincena = p_quincena);

    -- El ORDER BY va DENTRO de la subconsulta, no dentro del json_agg: es más
    -- claro y evita depender de cómo el agregado ve las columnas del alias.
    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON)
    INTO v_movimientos
    FROM (
        SELECT
            m.id,
            m.tipo_movimiento,
            CASE m.tipo_movimiento
                WHEN 1 THEN 'Consumo'
                WHEN 2 THEN 'Abono'
                ELSE 'Ajuste'
            END AS tipo_movimiento_nombre,
            m.monto,
            m.saldo_resultante,
            m.anio,
            m.mes,
            m.quincena,
            m.id_pedido,
            m.observacion,
            m.fecha_creacion
        FROM cxc_movimiento m
        WHERE m.id_persona = p_id_persona
          AND m.estado = 1
          AND (p_anio IS NULL OR m.anio = p_anio)
          AND (p_mes IS NULL OR m.mes = p_mes)
          AND (p_quincena IS NULL OR m.quincena = p_quincena)
        ORDER BY m.fecha_creacion ASC, m.id ASC
    ) x;

    RETURN json_build_object(
        'registro', json_build_object(
            'persona', v_persona,
            'periodo', json_build_object(
                'anio', p_anio,
                'mes', p_mes,
                'quincena', p_quincena
            ),
            'saldo_anterior', v_saldo_anterior,
            'total_cargos', v_cargos,
            'total_abonos', v_abonos,
            'saldo_actual', v_saldo,
            'movimientos', v_movimientos
        )
    );
END;
$function$;
