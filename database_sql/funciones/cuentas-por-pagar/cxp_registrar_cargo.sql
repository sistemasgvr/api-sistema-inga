-- Registro un cargo: una compra a crédito que aumenta lo que le debemos a un proveedor.
--
-- Esta es la función que **M14 va a llamar automáticamente** cuando un ítem del
-- gasto diario se marque como "a crédito". El parámetro p_id_gasto_diario
-- queda listo para ese enlace; hoy llega NULL porque M14 todavía no existe y
-- los cargos se cargan a mano.
--
-- El período (año, mes, semana) lo derivo de la fecha, no lo pido. La semana
-- ISO es la que importa acá: el abono a proveedores es semanal, así que el
-- reporte necesita agrupar por semana tal como se paga.
--
-- El saldo_resultante lo calculo y lo guardo en el momento. Lo hago así, y no
-- recalculándolo siempre desde cero, porque es una foto: permite reconstruir
-- el estado de la cuenta en cualquier punto del historial sin re-sumar todo.
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

    -- Requisito del alcance: la deuda se vincula a un proveedor, no a
    -- cualquier persona. Si alguien eligiera un cliente por error, la deuda
    -- aparecería en un reporte donde no tiene sentido.
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
