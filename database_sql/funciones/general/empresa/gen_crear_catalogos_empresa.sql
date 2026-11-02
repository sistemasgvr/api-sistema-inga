-- Catálogos base de una empresa: cliente «Clientes varios» (DNI 00000000, lo
-- exigen el cobro y la reemisión), categorías de gastos administrativos y de
-- gastos diarios. Solo crea lo que falta. Re-ejecutable.
DROP FUNCTION IF EXISTS gen_crear_catalogos_empresa(p_id_empresa BIGINT);
CREATE OR REPLACE FUNCTION gen_crear_catalogos_empresa(p_id_empresa BIGINT)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM gen_empresa WHERE id = p_id_empresa) THEN
        RETURN json_build_object('error', 'La empresa no existe');
    END IF;

    INSERT INTO cli_persona (
        id_empresa, tipo_persona, tipo_documento, num_documento, razon_social, nombres, es_cliente
    )
    SELECT p_id_empresa, 1, 1, '00000000', 'CLIENTES VARIOS', 'CLIENTES VARIOS', TRUE
    WHERE NOT EXISTS (
        SELECT 1
        FROM cli_persona p
        WHERE p.id_empresa = p_id_empresa
          AND p.tipo_documento = 1
          AND p.num_documento = '00000000'
    );

    INSERT INTO gad_categoria (id_empresa, nombre, tipo_gasto, orden)
    SELECT p_id_empresa, v.nombre, v.tipo_gasto, v.orden
    FROM (VALUES
        ('Alquiler del local',   1, 1),
        ('Servicios basicos',    1, 2),
        ('Sistemas y software',  1, 3),
        ('Mantenimiento',        2, 4),
        ('Utiles de oficina',    2, 5),
        ('Otros gastos',         2, 6)
    ) AS v(nombre, tipo_gasto, orden)
    WHERE NOT EXISTS (
        SELECT 1
        FROM gad_categoria c
        WHERE c.id_empresa = p_id_empresa
          AND c.id_categoria_padre IS NULL
          AND c.nombre = v.nombre
    );

    INSERT INTO gad_categoria (id_empresa, id_categoria_padre, nombre, tipo_gasto, orden)
    SELECT p_id_empresa, p.id, v.nombre, 1, v.orden
    FROM (VALUES
        ('Luz',      1),
        ('Agua',     2),
        ('Internet', 3)
    ) AS v(nombre, orden)
    JOIN gad_categoria p
      ON p.id_empresa = p_id_empresa
     AND p.id_categoria_padre IS NULL
     AND p.nombre = 'Servicios basicos'
    WHERE NOT EXISTS (
        SELECT 1
        FROM gad_categoria c
        WHERE c.id_categoria_padre = p.id
          AND c.nombre = v.nombre
    );

    INSERT INTO gdo_categoria (id_empresa, codigo, nombre, orden)
    SELECT p_id_empresa, v.codigo, v.nombre, v.orden
    FROM (VALUES
        ('PROCESADOS',    'Procesados',            1),
        ('ABARROTES',     'Abarrotes',             2),
        ('VERDURAS',      'Verduras y Frutas',     3),
        ('CARNES',        'Carnes y Pollo',        4),
        ('PESCADOS',      'Pescados y Mariscos',   5),
        ('DESCARTABLES',  'Descartables',          6),
        ('ASEO',          'Aseo y Limpieza',       7),
        ('LICORES',       'Licores y Gaseosas',    8),
        ('OTROS_GDO',     'Otros',                 9)
    ) AS v(codigo, nombre, orden)
    WHERE NOT EXISTS (
        SELECT 1
        FROM gdo_categoria c
        WHERE c.id_empresa = p_id_empresa
          AND c.codigo = v.codigo
    );

    RETURN json_build_object('id_empresa', p_id_empresa);
END;
$function$;
