DROP FUNCTION IF EXISTS gdo_obtener_insumo(p_id BIGINT, p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION gdo_obtener_insumo(p_id BIGINT, p_id_empresa BIGINT DEFAULT NULL)
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
            (
                SELECT COUNT(*)
                FROM gdo_gasto_detalle d
                WHERE d.id_insumo = i.id AND d.estado = 1
                  AND (p_id_empresa IS NULL OR d.id_empresa = p_id_empresa)
            ) AS veces_comprado,
            i.fecha_creacion,
            i.fecha_modificacion
        FROM gdo_insumo i
        INNER JOIN gdo_categoria c ON i.id_categoria = c.id AND (p_id_empresa IS NULL OR c.id_empresa = p_id_empresa)
        LEFT JOIN cli_persona p ON i.id_proveedor_habitual = p.id AND (p_id_empresa IS NULL OR p.id_empresa = p_id_empresa)
        WHERE i.id = p_id
          AND (p_id_empresa IS NULL OR i.id_empresa = p_id_empresa)
    ) x;

    RETURN json_build_object('registro', v_registro);
END;
$function$;