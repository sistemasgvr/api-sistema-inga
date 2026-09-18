-- Abro un turno de caja.
--
-- La base ya garantiza que no haya dos turnos abiertos en la misma caja, con el
-- índice parcial uq_caj_turno_abierto. Aun así valido acá antes de insertar,
-- porque si dejo que reviente el índice el usuario recibe un error técnico de
-- Postgres en vez de un mensaje que le diga quién tiene la caja tomada.
--
-- También bloqueo que el mismo cajero tenga dos turnos abiertos en cajas
-- distintas: una persona no puede estar en dos cajas a la vez, y si pasara,
-- los cobros se repartirían entre los dos turnos sin que nadie se dé cuenta.
CREATE OR REPLACE FUNCTION caj_abrir_turno(
    p_id_caja BIGINT,
    p_id_cajero BIGINT,
    p_monto_apertura NUMERIC DEFAULT 0,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id BIGINT;
    v_cajero_ocupado RECORD;
    v_turno_abierto RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM caj_caja WHERE id = p_id_caja AND estado = 1) THEN
        RETURN json_build_object('error', 'La caja indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth_usuario WHERE id = p_id_cajero AND estado = 1) THEN
        RETURN json_build_object('error', 'El cajero indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF COALESCE(p_monto_apertura, 0) < 0 THEN
        RETURN json_build_object('error', 'El monto de apertura no puede ser negativo', 'registro', NULL);
    END IF;

    -- ¿La caja ya está tomada?
    SELECT t.id, TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, '')) AS cajero
    INTO v_turno_abierto
    FROM caj_turno t
    INNER JOIN auth_usuario u ON t.id_cajero = u.id
    WHERE t.id_caja = p_id_caja AND t.estado_turno = 1 AND t.estado = 1
    LIMIT 1;

    IF FOUND THEN
        RETURN json_build_object(
            'error', 'Esta caja ya tiene un turno abierto a nombre de ' || v_turno_abierto.cajero ||
                     '. Debe cerrarse antes de abrir uno nuevo.',
            'registro', NULL
        );
    END IF;

    -- ¿El cajero ya tiene otra caja abierta?
    SELECT t.id, c.nombre AS caja
    INTO v_cajero_ocupado
    FROM caj_turno t
    INNER JOIN caj_caja c ON t.id_caja = c.id
    WHERE t.id_cajero = p_id_cajero AND t.estado_turno = 1 AND t.estado = 1
    LIMIT 1;

    IF FOUND THEN
        RETURN json_build_object(
            'error', 'Este cajero ya tiene un turno abierto en la caja ' || v_cajero_ocupado.caja,
            'registro', NULL
        );
    END IF;

    INSERT INTO caj_turno (
        id_caja,
        id_cajero,
        monto_apertura,
        estado_turno,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_caja,
        p_id_cajero,
        COALESCE(p_monto_apertura, 0),
        1, -- TURNO_ESTADO: 1 = ABIERTO
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN caj_obtener_turno(v_id);
END;
$function$;
