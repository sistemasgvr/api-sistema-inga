-- Traigo un trabajador por ID, con el acumulado de lo que se le ha pagado.
--
-- Crear y actualizar terminan llamando acá para devolver siempre el mismo
-- formato, sin importar por cuál operación se haya pasado.
--
-- No filtro por estado: necesito poder leer a un trabajador inactivo para
-- mostrar su ficha y para que el botón de reactivar tenga algo que mostrar.
CREATE OR REPLACE FUNCTION pla_obtener_trabajador(p_id BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(x) INTO v_registro
    FROM (
        SELECT
            t.id,
            t.id_sucursal,
            s.nombre AS nombre_sucursal,
            t.nombres,
            t.apellidos,
            TRIM(t.nombres || ' ' || t.apellidos) AS nombre_completo,
            t.num_documento,
            t.puesto,
            t.sueldo_referencial,
            t.estado,
            COALESCE((
                SELECT SUM(p.monto)
                FROM pla_pago p
                WHERE p.id_trabajador = t.id AND p.estado = 1
            ), 0) AS total_pagado_historico,
            COALESCE((
                SELECT COUNT(*)
                FROM pla_pago p
                WHERE p.id_trabajador = t.id AND p.estado = 1
            ), 0) AS cantidad_pagos,
            t.fecha_creacion,
            t.fecha_modificacion,
            t.id_usuario_creacion,
            uc.nombres AS nombre_usuario_creacion,
            t.id_usuario_modificacion,
            um.nombres AS nombre_usuario_modificacion
        FROM pla_trabajador t
        LEFT JOIN gen_sucursal s ON t.id_sucursal = s.id
        LEFT JOIN auth_usuario uc ON t.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuario um ON t.id_usuario_modificacion = um.id
        WHERE t.id = p_id
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
