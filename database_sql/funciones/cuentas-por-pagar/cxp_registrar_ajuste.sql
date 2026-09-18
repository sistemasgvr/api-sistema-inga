-- Registro un ajuste manual del saldo de un proveedor (tipo 3).
--
-- Existe por los casos que ni el cargo ni el abono cubren: un pago de más que
-- quedó a favor, una nota de crédito del proveedor, o un saldo inicial al
-- empezar a usar el sistema con deudas ya existentes.
--
-- A diferencia de cargo y abono, acá el monto **lleva signo**:
--   positivo → aumenta lo que debemos
--   negativo → reduce lo que debemos
--
-- Exijo motivo obligatorio. Un ajuste sin explicación es exactamente lo que
-- hace que nadie confíe en el saldo tres meses después.
CREATE OR REPLACE FUNCTION cxp_registrar_ajuste(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_motivo VARCHAR,
    p_fecha_movimiento DATE DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_fecha DATE;
    v_saldo NUMERIC(12,2);
    v_es_proveedor BOOLEAN;
    v_motivo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_movimiento, CURRENT_DATE);
    v_motivo := NULLIF(TRIM(p_motivo), '');

    SELECT es_proveedor INTO v_es_proveedor
    FROM cli_persona WHERE id = p_id_persona AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La persona indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_es_proveedor = FALSE THEN
        RETURN json_build_object(
            'error', 'Solo se puede ajustar la cuenta de una persona marcada como proveedor',
            'registro', NULL
        );
    END IF;

    IF p_monto IS NULL OR p_monto = 0 THEN
        RETURN json_build_object(
            'error', 'El monto del ajuste no puede ser cero. Usa positivo para aumentar la deuda y negativo para reducirla.',
            'registro', NULL
        );
    END IF;

    IF v_motivo IS NULL THEN
        RETURN json_build_object(
            'error', 'El motivo del ajuste es obligatorio: sin él, nadie sabe después por qué cambió el saldo',
            'registro', NULL
        );
    END IF;

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede registrar un ajuste con fecha futura', 'registro', NULL);
    END IF;

    v_saldo := cxp_calcular_saldo_proveedor(p_id_persona) + p_monto;

    -- Detalle importante: la restricción ck_cxp_monto exige monto > 0, así que
    -- NO puedo guardar un ajuste negativo tal cual. Y como
    -- cxp_calcular_saldo_proveedor suma el tipo 3 en positivo, guardar el valor
    -- absoluto haría que un ajuste a la baja se contara al revés.
    --
    -- Lo resuelvo guardando el ajuste como el tipo que le corresponde por su
    -- efecto: si aumenta la deuda va como cargo (1), si la reduce va como
    -- abono (2). El prefijo "AJUSTE" en la observación lo distingue de un
    -- movimiento normal, y el saldo siempre cuadra sin casos especiales.
    INSERT INTO cxp_movimiento (
        id_persona, tipo_movimiento, monto, saldo_resultante,
        fecha_movimiento, anio, mes, semana, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_persona,
        CASE WHEN p_monto > 0 THEN 1 ELSE 2 END,
        ABS(p_monto),
        v_saldo,
        v_fecha,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        EXTRACT(WEEK FROM v_fecha)::SMALLINT,
        'AJUSTE — ' || CASE WHEN p_monto > 0 THEN 'aumenta deuda: ' ELSE 'reduce deuda: ' END || v_motivo,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cxp_obtener_movimiento(v_id);
END;
$function$;
