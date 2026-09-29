CREATE OR REPLACE FUNCTION auth_listar_trabajadores_disponibles(
    p_id BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT t.id, t.nombres, t.apellidos, t.email, t.telefono,
               s.nombre AS nombre_sucursal
        FROM pla_trabajador t
        LEFT JOIN gen_sucursal s ON s.id = t.id_sucursal
        WHERE t.estado = 1 AND t.email IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM auth_usuario u WHERE u.id_trabajador = t.id
          )
          AND (p_id IS NULL OR t.id = p_id)
        ORDER BY t.apellidos, t.nombres, t.id
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
