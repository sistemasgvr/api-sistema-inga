-- Pagos de planilla del período. Un trabajador sin sucursal entra en cualquier
-- filtro de sucursal de su empresa.
DROP FUNCTION IF EXISTS rep_pagos_planilla(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT,
    p_id_sucursal BIGINT
);
CREATE OR REPLACE FUNCTION rep_pagos_planilla(
    p_fecha_desde DATE,
    p_fecha_hasta DATE,
    p_id_empresa BIGINT DEFAULT NULL,
    p_id_sucursal BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql
STABLE
AS $function$
    WITH medios AS (
        SELECT o.valor_entero AS medio_pago, o.nombre
        FROM gen_lista_opcion o
        JOIN gen_lista l ON l.id = o.id_lista
        WHERE l.codigo = 'MEDIO_PAGO'
    )
    SELECT COALESCE(json_agg(x ORDER BY x.fecha DESC, x.trabajador), '[]'::JSON)
    FROM (
        SELECT
            pp.id::INT AS id,
            to_char(pp.fecha_pago, 'YYYY-MM-DD') AS fecha,
            pp.id_trabajador::INT AS id_trabajador,
            TRIM(concat_ws(' ', t.nombres, t.apellidos)) AS trabajador,
            t.puesto,
            pp.anio::INT AS anio,
            pp.mes::INT AS mes,
            pp.quincena::INT AS quincena,
            pp.medio_pago::INT AS medio_pago,
            COALESCE(m.nombre, pp.medio_pago::TEXT) AS medio,
            pp.monto::FLOAT8 AS monto,
            pp.observacion
        FROM pla_pago pp
        JOIN pla_trabajador t ON t.id = pp.id_trabajador
        LEFT JOIN medios m ON m.medio_pago = pp.medio_pago
        WHERE pp.estado = 1
          AND pp.fecha_pago BETWEEN p_fecha_desde AND p_fecha_hasta
          AND (p_id_empresa IS NULL OR t.id_empresa = p_id_empresa)
          AND (p_id_sucursal IS NULL OR t.id_sucursal IS NULL OR t.id_sucursal = p_id_sucursal)
    ) x;
$function$;
