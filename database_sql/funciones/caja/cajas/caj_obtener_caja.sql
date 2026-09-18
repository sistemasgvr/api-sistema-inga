-- Traigo una caja por ID, con el turno abierto si lo tiene.
-- Crear y actualizar terminan llamando acá para devolver siempre el mismo formato.
CREATE OR REPLACE FUNCTION caj_obtener_caja(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.id_sucursal,
            s.nombre AS nombre_sucursal,
            c.codigo,
            c.nombre,
            c.estado,
            ta.id AS id_turno_abierto,
            ta.fecha_apertura AS turno_fecha_apertura,
            ta.monto_apertura AS turno_monto_apertura,
            ta.id_cajero AS turno_id_cajero,
            TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, '')) AS turno_cajero,
            (ta.id IS NOT NULL) AS tiene_turno_abierto,
            c.fecha_creacion,
            c.fecha_modificacion
        FROM caj_caja c
        INNER JOIN gen_sucursal s ON c.id_sucursal = s.id
        LEFT JOIN LATERAL (
            SELECT t2.id, t2.fecha_apertura, t2.monto_apertura, t2.id_cajero
            FROM caj_turno t2
            WHERE t2.id_caja = c.id AND t2.estado_turno = 1 AND t2.estado = 1
            LIMIT 1
        ) ta ON TRUE
        LEFT JOIN auth_usuario u ON ta.id_cajero = u.id
        WHERE c.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
