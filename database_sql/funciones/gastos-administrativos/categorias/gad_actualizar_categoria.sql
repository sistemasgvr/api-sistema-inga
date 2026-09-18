-- Actualizo una categoría de gasto. Lo que llega en NULL se queda como está.
--
-- No dejo cambiar el padre: mover una categoría de rama recalcularía los
-- totales históricos del reporte mensual y dejaría los meses ya cerrados
-- contando distinto que antes. Si hace falta reorganizar, se crea una nueva y
-- se da de baja la anterior.
--
-- Tampoco dejo cambiar el tipo (fijo/variable) de una categoría que ya tiene
-- gastos: pasaría lo mismo con los totales por tipo de los meses cerrados.
CREATE OR REPLACE FUNCTION gad_actualizar_categoria(
    p_id BIGINT,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_tipo_gasto SMALLINT DEFAULT NULL,
    p_orden INTEGER DEFAULT NULL,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo VARCHAR;
    v_nombre VARCHAR;
    v_actual RECORD;
    v_gastos INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := UPPER(NULLIF(TRIM(p_codigo), ''));
    v_nombre := NULLIF(TRIM(p_nombre), '');

    SELECT id, id_categoria_padre, tipo_gasto
    INTO v_actual
    FROM gad_categoria WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La categoría no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM gad_categoria WHERE codigo = v_codigo AND id <> p_id
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe otra categoría con el código ' || v_codigo,
            'registro', NULL
        );
    END IF;

    IF p_tipo_gasto IS NOT NULL AND p_tipo_gasto NOT IN (1, 2) THEN
        RETURN json_build_object('error', 'El tipo de gasto debe ser fijo o variable', 'registro', NULL);
    END IF;

    IF p_tipo_gasto IS NOT NULL AND p_tipo_gasto <> v_actual.tipo_gasto THEN
        -- Una subcategoría sigue el tipo de su padre, punto.
        IF v_actual.id_categoria_padre IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'Una subcategoría hereda el tipo de su categoría padre y no se puede cambiar por separado',
                'registro', NULL
            );
        END IF;

        SELECT COUNT(*) INTO v_gastos
        FROM gad_gasto WHERE id_categoria = p_id AND estado = 1;

        IF v_gastos > 0 THEN
            RETURN json_build_object(
                'error', 'No se puede cambiar el tipo: la categoría ya tiene ' || v_gastos ||
                         ' gasto(s) registrado(s) y cambiaría los totales de meses ya cerrados.',
                'registro', NULL
            );
        END IF;
    END IF;

    UPDATE gad_categoria
    SET
        codigo = COALESCE(v_codigo, codigo),
        nombre = COALESCE(v_nombre, nombre),
        tipo_gasto = COALESCE(p_tipo_gasto, tipo_gasto),
        orden = COALESCE(p_orden, orden),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id AND estado = 1;

    -- Si es una raíz y cambió de tipo, arrastro a sus hijas para no dejar la
    -- rama contradictoria (una subcategoría fija colgando de una variable).
    IF p_tipo_gasto IS NOT NULL AND v_actual.id_categoria_padre IS NULL THEN
        UPDATE gad_categoria
        SET tipo_gasto = p_tipo_gasto,
            id_usuario_modificacion = p_id_usuario_auditoria
        WHERE id_categoria_padre = p_id;
    END IF;

    RETURN gad_obtener_categoria(p_id);
END;
$function$;
