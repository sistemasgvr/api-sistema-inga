-- Dinero que entró o salió en un turno desde OTROS módulos.
--
-- La caja no es el único lugar donde se cobra o se paga: cuentas por cobrar
-- recibe abonos, y cuentas por pagar, gastos administrativos, planilla y las
-- compras del día pagan contra el turno. Cada uno guarda su id_turno y su
-- medio de pago, pero el turno no los veía: un pago a proveedor en efectivo no
-- bajaba el efectivo esperado y el arqueo cerraba con sobrante.
--
-- Esta función los junta en una sola forma. La usan caj_calcular_totales_turno
-- (para los totales y el efectivo esperado) y caj_resumen_turno (para la lista
-- de movimientos), así los dos leen exactamente lo mismo.
--
-- tipo_movimiento: 1 ingreso, 2 egreso (mismo criterio que caj_movimiento).
-- medio_pago:      1 efectivo, 2 yape, 3 tarjeta/transferencia. Solo el 1 toca
--                  el cajón; los demás se muestran pero no cuentan para el arqueo.
-- Las compras a crédito (forma_pago 3) no están: no sale dinero, nace una deuda.
CREATE OR REPLACE FUNCTION caj_movimientos_externos(p_id_turno BIGINT)
RETURNS TABLE (
    origen VARCHAR,
    origen_nombre VARCHAR,
    id BIGINT,
    tipo_movimiento SMALLINT,
    medio_pago SMALLINT,
    monto NUMERIC,
    motivo VARCHAR,
    nombre_registra VARCHAR,
    fecha_creacion TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $function$
    -- Abonos de clientes (cuentas por cobrar): entra dinero.
    SELECT 'CXC'::VARCHAR, 'Cuentas por cobrar'::VARCHAR, m.id, 1::SMALLINT, m.medio_pago, m.monto,
           ('Cobro a ' || COALESCE(
               NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
               p.razon_social))::VARCHAR,
           TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, ''))::VARCHAR,
           m.fecha_creacion
    FROM cxc_movimiento m
    JOIN cli_persona p ON p.id = m.id_persona
    LEFT JOIN auth_usuario_datos u ON u.id = m.id_usuario_creacion
    WHERE m.id_turno = p_id_turno AND m.tipo_movimiento = 2 AND m.estado = 1

    UNION ALL
    -- Abonos a proveedores (cuentas por pagar): sale dinero.
    SELECT 'CXP', 'Pago a proveedor', m.id, 2::SMALLINT, m.medio_pago, m.monto,
           ('Pago a ' || COALESCE(
               NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
               p.razon_social))::VARCHAR,
           TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, ''))::VARCHAR,
           m.fecha_creacion
    FROM cxp_movimiento m
    JOIN cli_persona p ON p.id = m.id_persona
    LEFT JOIN auth_usuario_datos u ON u.id = m.id_usuario_creacion
    WHERE m.id_turno = p_id_turno AND m.tipo_movimiento = 2 AND m.estado = 1

    UNION ALL
    -- Gastos administrativos (alquiler, luz, etc.).
    SELECT 'GASTO_ADM', 'Gasto administrativo', g.id, 2::SMALLINT, g.medio_pago, g.monto,
           g.concepto::VARCHAR,
           TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, ''))::VARCHAR,
           g.fecha_creacion
    FROM gad_gasto g
    LEFT JOIN auth_usuario_datos u ON u.id = g.id_usuario_creacion
    WHERE g.id_turno = p_id_turno AND g.estado = 1

    UNION ALL
    -- Pagos de planilla.
    SELECT 'PLANILLA', 'Planilla', pp.id, 2::SMALLINT, pp.medio_pago, pp.monto,
           ('Pago a ' || TRIM(COALESCE(t.nombres, '') || ' ' || COALESCE(t.apellidos, '')))::VARCHAR,
           TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, ''))::VARCHAR,
           pp.fecha_creacion
    FROM pla_pago pp
    JOIN pla_trabajador t ON t.id = pp.id_trabajador
    LEFT JOIN auth_usuario_datos u ON u.id = pp.id_usuario_creacion
    WHERE pp.id_turno = p_id_turno AND pp.estado = 1

    UNION ALL
    -- Compras del día pagadas al contado (forma_pago 1 efectivo, 2 Yape: mismos
    -- códigos que MEDIO_PAGO). El turno lo lleva la cabecera del día.
    SELECT 'COMPRA_DIA', 'Compra del día', det.id, 2::SMALLINT, det.forma_pago, det.subtotal,
           ('Compra: ' || COALESCE(i.nombre, pr.nombre))::VARCHAR,
           TRIM(COALESCE(u.nombres, '') || ' ' || COALESCE(u.apellidos, ''))::VARCHAR,
           det.fecha_creacion
    FROM gdo_gasto_detalle det
    JOIN gdo_gasto_dia d ON d.id = det.id_gasto_dia
    LEFT JOIN gdo_insumo i ON i.id = det.id_insumo
    LEFT JOIN pro_producto pr ON pr.id = det.id_producto
    LEFT JOIN auth_usuario_datos u ON u.id = det.id_usuario_creacion
    WHERE d.id_turno = p_id_turno AND d.estado = 1 AND det.estado = 1
      AND det.forma_pago IN (1, 2);
$function$;
