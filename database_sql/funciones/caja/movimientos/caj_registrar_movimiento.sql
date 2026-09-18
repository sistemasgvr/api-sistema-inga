-- Registro un ingreso o egreso de caja que no es una venta.
--
-- Casos típicos: pagar un delivery de gas, comprar hielo, un retiro parcial
-- para el banco, o poner sencillo en el cajón.
--
-- El signo NO va en el monto: la tabla tiene un CHECK (ck_caj_mov_monto) que
-- exige monto > 0 siempre. Lo que distingue sumar de restar es
-- tipo_movimiento: 1 = ingreso, 2 = egreso. Así nadie puede meter un egreso
-- negativo y hacer que la caja cuadre por accidente.
CREATE OR REPLACE FUNCTION caj_registrar_movimiento(
    p_id_turno BIGINT,
    p_tipo_movimiento SMALLINT,
    p_monto NUMERIC,
    p_motivo VARCHAR,
    p_id_usuario_autoriza BIGINT DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_estado_turno SMALLINT;
    v_motivo VARCHAR;
    v_totales JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_motivo := NULLIF(TRIM(p_motivo), '');

    SELECT estado_turno INTO v_estado_turno
    FROM caj_turno WHERE id = p_id_turno AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El turno no existe o fue anulado', 'registro', NULL);
    END IF;

    -- Sobre un turno cerrado no se toca nada: sus números ya quedaron
    -- congelados y cambiarlos invalidaría el arqueo que ya se firmó.
    IF v_estado_turno = 2 THEN
        RETURN json_build_object(
            'error', 'No se pueden registrar movimientos en un turno cerrado',
            'registro', NULL
        );
    END IF;

    IF p_tipo_movimiento NOT IN (1, 2) THEN
        RETURN json_build_object('error', 'El tipo de movimiento debe ser ingreso o egreso', 'registro', NULL);
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_motivo IS NULL THEN
        RETURN json_build_object(
            'error', 'El motivo es obligatorio: sin él, al cerrar nadie sabe por qué salió ese dinero',
            'registro', NULL
        );
    END IF;

    -- Un egreso no puede dejar el cajón en negativo. Comparo contra el efectivo
    -- esperado del momento, que ya descuenta los egresos anteriores.
    IF p_tipo_movimiento = 2 THEN
        v_totales := caj_calcular_totales_turno(p_id_turno)::JSONB;

        IF p_monto > (v_totales->>'efectivo_esperado')::NUMERIC THEN
            RETURN json_build_object(
                'error', 'El egreso supera el efectivo disponible en caja (S/ ' ||
                         TO_CHAR((v_totales->>'efectivo_esperado')::NUMERIC, 'FM999999990.00') || ')',
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO caj_movimiento (
        id_turno,
        tipo_movimiento,
        monto,
        motivo,
        id_usuario_autoriza,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_turno,
        p_tipo_movimiento,
        p_monto,
        v_motivo,
        p_id_usuario_autoriza,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Devuelvo el turno completo y no solo el movimiento: la pantalla necesita
    -- refrescar el efectivo esperado, que acaba de cambiar.
    RETURN caj_obtener_turno(p_id_turno);
END;
$function$;
