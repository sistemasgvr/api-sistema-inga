-- Vuelve a calcular el cierre de un turno YA CERRADO cuando se corrige una
-- venta suya (por ejemplo, un pago que pasó de efectivo a Yape).
DROP FUNCTION IF EXISTS caj_recalcular_cierre_turno(
    p_id BIGINT,
    p_nota VARCHAR,
    p_id_usuario_auditoria BIGINT
);  
CREATE OR REPLACE FUNCTION caj_recalcular_cierre_turno(
    p_id BIGINT,
    p_nota VARCHAR,
    p_id_usuario_auditoria BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_esperado NUMERIC(12,2);
BEGIN
    PERFORM 1 FROM caj_turno WHERE id = p_id AND estado = 1 AND estado_turno = 2 FOR UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    v_esperado := (caj_calcular_totales_turno(p_id)::JSONB->>'efectivo_esperado')::NUMERIC;

    UPDATE caj_turno
    SET monto_cierre_sistema = v_esperado,
        monto_diferencia = v_esperado - COALESCE(monto_cierre_declarado, 0),
        -- La columna admite 255 caracteres: si no entra todo, se conserva lo más reciente.
        observacion = right(TRIM(BOTH ' ' FROM
            COALESCE(observacion || ' | ', '') || COALESCE(NULLIF(TRIM(p_nota), ''), '')), 255),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = p_id;
END;
$function$;
