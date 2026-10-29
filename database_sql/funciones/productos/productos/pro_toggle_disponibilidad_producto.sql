DROP FUNCTION IF EXISTS pro_toggle_disponibilidad_producto(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT,
    p_id_empresa BIGINT
);
CREATE OR REPLACE FUNCTION pro_toggle_disponibilidad_producto(
    p_id BIGINT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL,
    p_id_empresa BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nuevo_estado BOOLEAN;
    v_empresa BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_empresa := COALESCE(p_id_empresa, (SELECT p.id_empresa FROM pro_producto p WHERE p.id = p_id));

    SELECT NOT disponible_venta INTO v_nuevo_estado
    FROM pro_producto
    WHERE id = p_id AND estado = 1
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Producto no encontrado o inactivo', 'registro', NULL);
    END IF;

    IF v_nuevo_estado AND NOT EXISTS (
        SELECT 1 FROM pro_producto p JOIN pro_tipo_producto t ON t.id=p.tipo_producto
        WHERE p.id=p_id AND t.estado=1 AND t.permite_venta
          AND (v_empresa IS NULL OR p.id_empresa = v_empresa)
    ) THEN
        RETURN json_build_object('error', 'Este tipo de producto no permite venta', 'registro', NULL);
    END IF;

    UPDATE pro_producto
    SET disponible_venta = v_nuevo_estado,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND (v_empresa IS NULL OR id_empresa = v_empresa);

    RETURN pro_obtener_producto(p_id, v_empresa);
END;
$function$;