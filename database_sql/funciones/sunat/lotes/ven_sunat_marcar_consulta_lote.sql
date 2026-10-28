-- Registra una consulta del ticket (para espaciar las siguientes).
DROP FUNCTION IF EXISTS ven_sunat_marcar_consulta_lote(p_id_lote BIGINT);
CREATE OR REPLACE FUNCTION ven_sunat_marcar_consulta_lote(p_id_lote BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE ven_sunat_lote
    SET intentos_consulta = intentos_consulta + 1,
        fecha_consulta = CURRENT_TIMESTAMP
    WHERE id = p_id_lote;

    RETURN json_build_object('actualizado', FOUND);
END;
$function$;
