-- Actualizo un gasto administrativo. Lo que llega en NULL se queda como está.
--
-- Si cambia la fecha, recalculo anio/mes: son datos derivados y dejarlos
-- desincronizados haría que el gasto apareciera en el mes equivocado del
-- reporte mientras su fecha dice otra cosa.
--
-- No dejo editar un gasto en efectivo cuyo turno ya se cerró: ese turno se
-- arqueó contra el conteo físico y cambiar el monto ahora invalidaría la
-- diferencia que quedó firmada. Para eso está la anulación.
CREATE OR REPLACE FUNCTION gad_actualizar_gasto(
    p_id BIGINT,
    p_id_categoria BIGINT DEFAULT NULL,
    p_concepto VARCHAR DEFAULT NULL,
    p_monto NUMERIC DEFAULT NULL,
    p_fecha_gasto DATE DEFAULT NULL,
    p_medio_pago SMALLINT DEFAULT NULL,
    p_id_persona BIGINT DEFAULT NULL,
    p_num_comprobante VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_actual RECORD;
    v_estado_turno SMALLINT;
    v_fecha DATE;
    v_concepto VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_concepto := NULLIF(TRIM(p_concepto), '');

    SELECT g.medio_pago, g.id_turno, g.fecha_gasto
    INTO v_actual
    FROM gad_gasto g WHERE g.id = p_id AND g.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El gasto no existe o fue anulado', 'registro', NULL);
    END IF;

    IF v_actual.medio_pago = 1 AND v_actual.id_turno IS NOT NULL THEN
        SELECT estado_turno INTO v_estado_turno
        FROM caj_turno WHERE id = v_actual.id_turno;

        IF v_estado_turno = 2 THEN
            RETURN json_build_object(
                'error', 'No se puede editar: el gasto fue en efectivo y su turno de caja ya está cerrado y arqueado. Anúlalo y registra uno nuevo.',
                'registro', NULL
            );
        END IF;
    END IF;

    v_fecha := COALESCE(p_fecha_gasto, v_actual.fecha_gasto);

    IF v_fecha > CURRENT_DATE THEN
        RETURN json_build_object('error', 'No se puede fechar un gasto en el futuro', 'registro', NULL);
    END IF;

    IF p_monto IS NOT NULL AND p_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF p_id_categoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gad_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'La categoría indicada no existe o está inactiva',
            'registro', NULL
        );
    END IF;

    IF p_medio_pago IS NOT NULL AND p_medio_pago NOT IN (1, 2, 3) THEN
        RETURN json_build_object(
            'error', 'El medio de pago debe ser efectivo, Yape o tarjeta/transferencia',
            'registro', NULL
        );
    END IF;

    IF p_id_persona IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_persona WHERE id = p_id_persona AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El proveedor indicado no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    UPDATE gad_gasto
    SET
        id_categoria = COALESCE(p_id_categoria, id_categoria),
        concepto = COALESCE(v_concepto, concepto),
        monto = COALESCE(p_monto, monto),
        fecha_gasto = v_fecha,
        -- Derivados de la fecha: siempre en sincronía con ella.
        anio = EXTRACT(YEAR FROM v_fecha)::SMALLINT,
        mes = EXTRACT(MONTH FROM v_fecha)::SMALLINT,
        medio_pago = COALESCE(p_medio_pago, medio_pago),
        id_persona = COALESCE(p_id_persona, id_persona),
        num_comprobante = COALESCE(NULLIF(TRIM(p_num_comprobante), ''), num_comprobante),
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    RETURN gad_obtener_gasto(p_id);
END;
$function$;
