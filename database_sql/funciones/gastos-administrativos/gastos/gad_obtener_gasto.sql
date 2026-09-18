-- Traigo un gasto administrativo por ID.
-- Registrar y actualizar terminan llamando acá para devolver el mismo shape.
CREATE OR REPLACE FUNCTION gad_obtener_gasto(p_id BIGINT)
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
            g.id,
            g.id_categoria,
            c.nombre AS nombre_categoria,
            c.codigo AS codigo_categoria,
            -- Si es subcategoría, mando también el nombre de la rama para
            -- poder mostrar "Servicios · Luz" sin otra consulta.
            c.id_categoria_padre,
            p.nombre AS nombre_categoria_padre,
            c.tipo_gasto,
            CASE c.tipo_gasto WHEN 1 THEN 'Fijo' ELSE 'Variable' END AS tipo_gasto_nombre,
            g.concepto,
            g.monto,
            g.fecha_gasto,
            g.anio,
            g.mes,
            g.medio_pago,
            lo.nombre AS medio_pago_nombre,
            g.num_comprobante,
            g.id_persona,
            per.razon_social,
            g.id_turno,
            caj.nombre AS nombre_caja,
            g.id_sucursal,
            suc.nombre AS nombre_sucursal,
            g.observacion,
            g.estado,
            g.fecha_creacion,
            TRIM(COALESCE(uc.nombres, '') || ' ' || COALESCE(uc.apellidos, '')) AS nombre_usuario_creacion
        FROM gad_gasto g
        INNER JOIN gad_categoria c ON g.id_categoria = c.id
        LEFT JOIN gad_categoria p ON c.id_categoria_padre = p.id
        LEFT JOIN cli_persona per ON g.id_persona = per.id
        LEFT JOIN caj_turno tu ON g.id_turno = tu.id
        LEFT JOIN caj_caja caj ON tu.id_caja = caj.id
        LEFT JOIN gen_sucursal suc ON g.id_sucursal = suc.id
        LEFT JOIN auth_usuario uc ON g.id_usuario_creacion = uc.id
        LEFT JOIN gen_lista_opcion lo ON lo.valor_entero = g.medio_pago
            AND lo.id_lista = (SELECT id FROM gen_lista WHERE codigo = 'MEDIO_PAGO')
        WHERE g.id = p_id
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
