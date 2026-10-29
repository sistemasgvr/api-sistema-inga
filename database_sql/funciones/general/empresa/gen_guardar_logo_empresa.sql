-- Logo de la empresa: URL pública en Storage y versión blanco y negro (base64) para
-- tickets. NULL en ambos lo quita.
DROP FUNCTION IF EXISTS gen_guardar_logo_empresa(
    p_id_empresa BIGINT,
    p_logo_url TEXT,
    p_logo_ticket TEXT,
    p_id_usuario_auditoria BIGINT
);
CREATE OR REPLACE FUNCTION gen_guardar_logo_empresa(
    p_id_empresa BIGINT,
    p_logo_url TEXT,
    p_logo_ticket TEXT,
    p_id_usuario_auditoria BIGINT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE gen_empresa
    SET logo_url = p_logo_url,
        logo_ticket = p_logo_ticket,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = p_id_empresa;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La empresa no existe', 'registro', NULL);
    END IF;

    RETURN gen_obtener_empresa(p_id_empresa);
END;
$function$;
