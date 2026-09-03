CREATE OR REPLACE FUNCTION pro_toggle_disponibilidad_producto(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nuevo_estado BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT NOT disponible_venta INTO v_nuevo_estado
    FROM pro_producto
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Producto no encontrado o inactivo', 'registro', NULL);
    END IF;

    UPDATE pro_producto
    SET disponible_venta = v_nuevo_estado,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN pro_obtener_producto(p_id);
END;
$function$;