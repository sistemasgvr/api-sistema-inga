-- Multiempresa: funciones de la fase 3 que su migración no cargaba (solo cargaba
-- las de productos). Personas, convenios, roles, insumos de gastos diarios y
-- saldos / movimientos de CxC y CxP pasan a la versión con p_id_empresa, que es
-- la que llama el API. Re-ejecutable.

-- Personas (cli_validar_datos_persona primero: la usan crear y actualizar)
\ir ../funciones/personas/personas/cli_validar_datos_persona.sql
\ir ../funciones/personas/personas/cli_obtener_persona.sql
\ir ../funciones/personas/personas/cli_listar_personas.sql
\ir ../funciones/personas/personas/cli_buscar_personas.sql
\ir ../funciones/personas/personas/cli_crear_persona.sql
\ir ../funciones/personas/personas/cli_actualizar_persona.sql
\ir ../funciones/personas/personas/cli_eliminar_persona.sql
\ir ../funciones/personas/personas/cli_activar_persona.sql

-- Convenios
\ir ../funciones/personas/convenios/cli_obtener_convenio.sql
\ir ../funciones/personas/convenios/cli_listar_convenios.sql
\ir ../funciones/personas/convenios/cli_crear_convenio.sql
\ir ../funciones/personas/convenios/cli_actualizar_convenio.sql
\ir ../funciones/personas/convenios/cli_eliminar_convenio.sql
\ir ../funciones/personas/convenios/cli_activar_convenio.sql

-- Roles
\ir ../funciones/roles/auth_listar_roles.sql

-- Insumos de gastos diarios
\ir ../funciones/gastos-diarios/insumos/gdo_listar_insumos.sql
\ir ../funciones/gastos-diarios/insumos/gdo_crear_insumo.sql
\ir ../funciones/gastos-diarios/insumos/gdo_actualizar_insumo.sql
\ir ../funciones/gastos-diarios/insumos/gdo_toggle_insumo.sql

-- Cuentas por cobrar y por pagar
\ir ../funciones/cuentas-por-cobrar/cxc_listar_saldos.sql
\ir ../funciones/cuentas-por-cobrar/cxc_listar_movimientos.sql
\ir ../funciones/cuentas-por-pagar/cxp_listar_saldos.sql

-- ---------------------------------------------------------------------------
-- Firmas antiguas: quita las versiones de una función cuyos argumentos son un
-- prefijo de la versión más nueva (p. ej. sin p_id_empresa). Si quedaran, una
-- llamada con menos argumentos sería ambigua («la función no es única»).
-- ---------------------------------------------------------------------------
DO $mig$
DECLARE
    f RECORD;
BEGIN
    FOR f IN
        SELECT viejo.oid::regprocedure AS firma
        FROM pg_proc viejo
        JOIN pg_proc nuevo
          ON nuevo.proname = viejo.proname
         AND nuevo.pronamespace = viejo.pronamespace
         AND nuevo.pronargs > viejo.pronargs
         AND (nuevo.proargtypes::OID[])[0:viejo.pronargs - 1] = (viejo.proargtypes::OID[])[0:viejo.pronargs - 1]
        WHERE viejo.pronamespace = 'public'::regnamespace
          AND viejo.prokind = 'f'
          AND nuevo.prokind = 'f'
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %s', f.firma);
    END LOOP;
END $mig$;
