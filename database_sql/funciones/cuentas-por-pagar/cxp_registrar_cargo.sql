-- Registro un cargo: una compra a crédito que aumenta lo que le debemos a un proveedor.
-- También la llama gastos diarios cuando una línea se marca a crédito.
DROP FUNCTION IF EXISTS cxp_registrar_cargo(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_fecha_movimiento DATE,
    p_num_comprobante VARCHAR,
    p_id_gasto_diario BIGINT,
    p_observacion VARCHAR,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION cxp_registrar_cargo(
    p_id_persona BIGINT,
    p_monto NUMERIC,
    p_fecha_movimiento DATE DEFAULT NULL,
    p_num_comprobante VARCHAR DEFAULT NULL,
    p_id_gasto_diario BIGINT DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
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
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha := COALESCE(p_fecha_movimiento, CURRENT_DATE);

    SELECT es_proveedor INTO v_es_proveedor
    FROM cli_persona WHERE id = p_id_persona AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La persona indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_es_proveedor = FALSE THEN
        RETURN json_build_object(
            'error', 'Solo se puede registrar deuda a una persona marcada como proveedor',
            'registro', NULL
        );
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto del cargo debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede registrar un cargo con fecha futura', 'registro', NULL);
    END IF;

    v_saldo := cxp_calcular_saldo_proveedor(p_id_persona) + p_monto;

    INSERT INTO cxp_movimiento (
        id_persona, id_gasto_diario, tipo_movimiento, monto, saldo_resultante,
        fecha_movimiento, anio, mes, semana,
        num_comprobante, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_persona, p_id_gasto_diario, 1, p_monto, v_saldo,
        v_fecha,
        EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        -- ISO: la semana 1 es la que contiene el primer jueves del año.
        EXTRACT(WEEK FROM v_fecha)::SMALLINT,
        NULLIF(TRIM(p_num_comprobante), ''),
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cxp_obtener_movimiento(v_id);
END;
$function$;
