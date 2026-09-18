-- Traigo un insumo de la lista maestra por ID.
-- Crear y actualizar terminan llamando acá para devolver el mismo shape.
CREATE OR REPLACE FUNCTION gdo_obtener_insumo(p_id BIGINT)
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
            i.id,
            i.id_categoria,
            c.nombre AS nombre_categoria,
            i.nombre,
            i.precio_referencial,
            i.id_proveedor_habitual,
            COALESCE(
                NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
                p.razon_social
            ) AS nombre_proveedor_habitual,
            i.estado,
            -- Cuántas veces se compró. Sirve para avisar antes de dar de baja
            -- y para saber si un insumo realmente se usa.
            (
                SELECT COUNT(*)
                FROM gdo_gasto_detalle d
                WHERE d.id_insumo = i.id AND d.estado = 1
            ) AS veces_comprado,
            i.fecha_creacion,
            i.fecha_modificacion
        FROM gdo_insumo i
        INNER JOIN gdo_categoria c ON i.id_categoria = c.id
        LEFT JOIN cli_persona p ON i.id_proveedor_habitual = p.id
        WHERE i.id = p_id
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
