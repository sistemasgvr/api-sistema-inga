-- =============================================================================
-- SISTEMA INGA — PostgreSQL
-- Esquema operativo de restaurante (carta + menú + bar + almacén + recetario)
-- =============================================================================
--
-- MODELO DE NEGOCIO (reunión con administración Inga)
-- -----------------------------------------------------------------------------
-- Hay DOS inventarios. No mezclarlos:
--
--  1) ALMACÉN (insumo crudo / a granel)
--     Compra semanal: sacos, planchas, cajas, botellas, atún, fideos, licores.
--     Salida diaria a cocina o barra (hoy: foto WhatsApp + Excel).
--     El sistema registra ingreso por compra y salida por vale, con evidencia.
--     El crudo NO entra a la receta del plato.
--     Flujo cocina: requerimiento chef → salida de almacén (foto) → producción
--     (chef declara presas/potes/onzas) → recién ahí existe stock recetario.
--
--  2) PRODUCCIÓN / RECETARIO (insumo ya procesado / porcionado)
--     El chef procesa fuera del sistema (8 patos → 45 presas; culantro → 30 potes
--     de salsa; caja de pisco → onzas). Luego se INGRESA al stock recetario.
--     Cada plato/trago tiene receta en gramos, ml, onzas, presas, porciones.
--     Cada venta explota la receta y descuenta este stock (ingreso − consumo).
--     Alerta cuando stock_actual <= stock_minimo (chef + administración).
--
--  Bar: tragos en ONZAS agregadas por insumo (pisco, whisky, ron, tequila, vodka,
--  vino gato para preparación). No se controla botella física abierta.
--  Vino de mesa: se vende y se stockea por BOTELLA (unidad).
--
--  Pagos: efectivo, YAPE, Visa/tarjeta, crédito (consorcio GVR, 4G, ApuSalud,
--  Jurisconta, etc.). Reporte quincenal / mensual por persona y por convenio.
--
--  Comandas: impresora cocina (platos), caja (bebidas + comprobantes),
--  barra (tragos). KDS opcional sobre el mismo ruteo.
--
--  Facturación electrónica: el esquema deja comprobante + estado SUNAT.
--  La integración con el proveedor se conecta después; no se asume GRE/XML aquí.
--
-- CONVENCIONES
--  - Prefijos por módulo (auth_, gen_, cli_, pro_, alm_, prod_, com_, caj_,
--    ven_, kds_, cxc_).
--  - estado: 1 activo / 0 inactivo (baja lógica). Nunca borrar histórico.
--  - Montos NUMERIC(12,2). Cantidades/stock NUMERIC(14,4).
--  - Fechas TIMESTAMPTZ. IDs BIGINT IDENTITY (tickets y kardex legibles).
--  - Catálogos de negocio en gen_lista / gen_lista_opcion (semilla al final).
--  - El API actualiza stock; kardex es la fuente de verdad de movimientos.
-- =============================================================================

-- Requiere PostgreSQL 12+. Tipos: TIMESTAMPTZ, NUMERIC, IDENTITY.
-- TIME ZONE solo afecta esta sesión; las columnas TIMESTAMPTZ guardan UTC.
SET TIME ZONE 'America/Lima';

-- -----------------------------------------------------------------------------
-- Auditoría: fecha_modificacion automática
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_fecha_modificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.fecha_modificacion := CLOCK_TIMESTAMP();
    RETURN NEW;
END;
$$;

-- =============================================================================
-- MÓDULO AUTH (roles primero; usuario va después de gen_sucursal)
-- =============================================================================

-- Utilidad: roles del sistema (admin, cajero, mozo, chef, barman).
CREATE TABLE IF NOT EXISTS auth_rol (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    descripcion             VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_auth_rol_codigo UNIQUE (codigo)
);

-- Utilidad: permisos por módulo para autorizar acciones en el API.
CREATE TABLE IF NOT EXISTS auth_permiso (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                  VARCHAR(80)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    descripcion             VARCHAR(255),
    modulo                  VARCHAR(50)  NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_auth_permiso_codigo UNIQUE (codigo)
);

-- Utilidad: qué permisos tiene cada rol.
CREATE TABLE IF NOT EXISTS auth_rol_permiso (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_rol                  BIGINT       NOT NULL,
    id_permiso              BIGINT       NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_auth_rol_permiso UNIQUE (id_rol, id_permiso),
    CONSTRAINT fk_rol_perm_rol FOREIGN KEY (id_rol) REFERENCES auth_rol (id),
    CONSTRAINT fk_rol_perm_permiso FOREIGN KEY (id_permiso) REFERENCES auth_permiso (id)
);

-- =============================================================================
-- MÓDULO GENERAL
-- =============================================================================

-- Utilidad: cabecera de catálogos (tipos, estados, medios de pago, etc.).
CREATE TABLE IF NOT EXISTS gen_lista (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    descripcion             VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_lista_codigo UNIQUE (codigo)
);

-- Utilidad: valores de cada catálogo (código, nombre y entero usado en las tablas).
CREATE TABLE IF NOT EXISTS gen_lista_opcion (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_lista                BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    descripcion             VARCHAR(255),
    valor_entero            INTEGER,
    orden                   INTEGER      NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_lista_opcion UNIQUE (id_lista, codigo),
    CONSTRAINT fk_lista_opcion_lista FOREIGN KEY (id_lista) REFERENCES gen_lista (id)
);

-- Utilidad: contado o crédito (quincena / 30 días) para compras y convenios.
CREATE TABLE IF NOT EXISTS gen_condicion_pago (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    dias_credito            INTEGER      NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_condicion_pago UNIQUE (codigo)
);

-- Utilidad: país (ubigeo / facturación).
CREATE TABLE IF NOT EXISTS gen_pais (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                  VARCHAR(100) NOT NULL,
    codigo_iso              VARCHAR(10)  NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    CONSTRAINT uq_gen_pais_iso UNIQUE (codigo_iso)
);

-- Utilidad: departamento del ubigeo Perú.
CREATE TABLE IF NOT EXISTS gen_departamento (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pais                 BIGINT       NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    CONSTRAINT fk_departamento_pais FOREIGN KEY (id_pais) REFERENCES gen_pais (id)
);

-- Utilidad: provincia del ubigeo Perú.
CREATE TABLE IF NOT EXISTS gen_provincia (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_departamento         BIGINT       NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    CONSTRAINT fk_provincia_departamento FOREIGN KEY (id_departamento) REFERENCES gen_departamento (id)
);

-- Utilidad: distrito y código ubigeo para empresa, sucursal y personas.
CREATE TABLE IF NOT EXISTS gen_distrito (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_provincia            BIGINT       NOT NULL,
    codigo_ubigeo           VARCHAR(6),
    nombre                  VARCHAR(100) NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    CONSTRAINT fk_distrito_provincia FOREIGN KEY (id_provincia) REFERENCES gen_provincia (id)
);

-- Utilidad: razón social y RUC del restaurante (Inga).
CREATE TABLE IF NOT EXISTS gen_empresa (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ruc                     VARCHAR(11)  NOT NULL,
    razon_social            VARCHAR(255) NOT NULL,
    nombre_comercial        VARCHAR(255),
    direccion               TEXT,
    id_distrito             BIGINT,
    telefono                VARCHAR(20),
    email                   VARCHAR(100),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_empresa_ruc UNIQUE (ruc),
    CONSTRAINT fk_empresa_distrito FOREIGN KEY (id_distrito) REFERENCES gen_distrito (id)
);

-- Utilidad: local físico; hoy uno, preparado para más sedes.
CREATE TABLE IF NOT EXISTS gen_sucursal (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa              BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    direccion               TEXT,
    telefono                VARCHAR(20),
    id_distrito             BIGINT,
    es_principal            BOOLEAN      NOT NULL DEFAULT FALSE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_sucursal_codigo UNIQUE (id_empresa, codigo),
    CONSTRAINT fk_sucursal_empresa FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id),
    CONSTRAINT fk_sucursal_distrito FOREIGN KEY (id_distrito) REFERENCES gen_distrito (id)
);

-- Utilidad: usuarios que entran al sistema (login, PIN de mozo).
CREATE TABLE IF NOT EXISTS auth_usuario (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username                VARCHAR(80)  NOT NULL,
    email                   VARCHAR(255) NOT NULL,
    password_hash           VARCHAR(255) NOT NULL,
    pin_hash                VARCHAR(255),
    nombres                 VARCHAR(100) NOT NULL,
    apellidos               VARCHAR(100) NOT NULL,
    telefono                VARCHAR(20),
    id_sucursal_default     BIGINT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_auth_usuario_username UNIQUE (username),
    CONSTRAINT uq_auth_usuario_email UNIQUE (email),
    CONSTRAINT ck_auth_usuario_estado CHECK (estado IN (0, 1)),
    CONSTRAINT fk_usuario_sucursal_default FOREIGN KEY (id_sucursal_default) REFERENCES gen_sucursal (id)
);

-- Utilidad: roles asignados a cada usuario.
CREATE TABLE IF NOT EXISTS auth_usuario_rol (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario              BIGINT       NOT NULL,
    id_rol                  BIGINT       NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_auth_usuario_rol UNIQUE (id_usuario, id_rol),
    CONSTRAINT fk_usr_rol_usuario FOREIGN KEY (id_usuario) REFERENCES auth_usuario (id),
    CONSTRAINT fk_usr_rol_rol FOREIGN KEY (id_rol) REFERENCES auth_rol (id)
);

-- Utilidad: sesiones activas (refresh token, IP, cierre).
CREATE TABLE IF NOT EXISTS auth_sesion (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario              BIGINT       NOT NULL,
    refresh_token_hash      VARCHAR(255) NOT NULL,
    ip                      VARCHAR(45),
    user_agent              VARCHAR(255),
    fecha_inicio            TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion        TIMESTAMPTZ  NOT NULL,
    fecha_fin               TIMESTAMPTZ,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sesion_usuario FOREIGN KEY (id_usuario) REFERENCES auth_usuario (id)
);

-- tipo_almacen (gen_lista ALMACEN_TIPO):
--   1 CRUDO          almacén físico de insumos a granel (Inga tiene 2)
--   2 PRODUCCION_COCINA  stock recetario de platos (presas, salsas, porciones)
--   3 PRODUCCION_BARRA   stock recetario de tragos (onzas) y botellas de vino
-- Utilidad: almacenes crudos (2 físicos) y de producción (cocina / barra).
CREATE TABLE IF NOT EXISTS gen_almacen (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    descripcion             VARCHAR(255),
    tipo_almacen            SMALLINT     NOT NULL,
    es_principal            BOOLEAN      NOT NULL DEFAULT FALSE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_almacen_codigo UNIQUE (id_sucursal, codigo),
    CONSTRAINT fk_almacen_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id)
);

-- Estaciones de impresión / KDS: COCINA, BARRA, CAJA
-- Utilidad: impresoras/KDS: cocina (platos), caja (bebidas + boletas), barra (tragos).
CREATE TABLE IF NOT EXISTS gen_estacion (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    tipo_estacion           SMALLINT     NOT NULL,
    impresora_nombre        VARCHAR(100),
    impresora_ip            VARCHAR(45),
    usa_kds                 BOOLEAN      NOT NULL DEFAULT FALSE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_estacion UNIQUE (id_sucursal, codigo),
    CONSTRAINT fk_estacion_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id)
);

-- Utilidad: series y correlativos de pedidos, salidas, comprobantes, etc.
CREATE TABLE IF NOT EXISTS gen_correlativo (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    tipo_documento          SMALLINT     NOT NULL,
    serie                   VARCHAR(10)  NOT NULL,
    ultimo_numero           BIGINT       NOT NULL DEFAULT 0,
    longitud                INTEGER      NOT NULL DEFAULT 8,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_correlativo UNIQUE (id_sucursal, tipo_documento, serie),
    CONSTRAINT fk_correlativo_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id)
);

-- Utilidad: cuentas bancarias de la empresa (depósitos, pagos a proveedores).
CREATE TABLE IF NOT EXISTS gen_cuenta_bancaria (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa              BIGINT       NOT NULL,
    banco                   SMALLINT     NOT NULL,
    tipo_cuenta             SMALLINT     NOT NULL,
    numero_cuenta           VARCHAR(50)  NOT NULL,
    cci                     VARCHAR(50),
    titular                 VARCHAR(255),
    moneda                  SMALLINT     NOT NULL DEFAULT 1,
    es_principal            BOOLEAN      NOT NULL DEFAULT FALSE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cuenta_bancaria_empresa FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id)
);

-- Credenciales SUNAT / PSE: guardar cifradas en el API, no en texto plano.
-- Utilidad: conexión futura a facturación electrónica (credenciales cifradas).
CREATE TABLE IF NOT EXISTS gen_configuracion_sunat (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa              BIGINT       NOT NULL,
    proveedor_ose           VARCHAR(80),
    usuario_sol_cifrado     TEXT,
    clave_sol_cifrada       TEXT,
    certificado_cifrado     TEXT,
    id_ambiente             SMALLINT     NOT NULL DEFAULT 1,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_gen_config_sunat_empresa UNIQUE (id_empresa),
    CONSTRAINT fk_config_sunat_empresa FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id)
);

-- =============================================================================
-- CLIENTES / PROVEEDORES / CONSORCIO
-- =============================================================================

-- Convenio de crédito (GVR, 4G, ApuSalud, Jurisconta, ...)
-- Utilidad: empresas del consorcio con crédito (GVR, 4G, ApuSalud, Jurisconta).
CREATE TABLE IF NOT EXISTS cli_convenio (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(150) NOT NULL,
    id_condicion_pago       BIGINT       NOT NULL,
    limite_credito          NUMERIC(12, 2) NOT NULL DEFAULT 0,
    corte_quincenal         BOOLEAN      NOT NULL DEFAULT TRUE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cli_convenio_codigo UNIQUE (codigo),
    CONSTRAINT fk_convenio_condicion FOREIGN KEY (id_condicion_pago) REFERENCES gen_condicion_pago (id)
);

-- Utilidad: clientes, proveedores y consumidores a crédito (ej. Billy Reaño).
CREATE TABLE IF NOT EXISTS cli_persona (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_persona            SMALLINT     NOT NULL,
    tipo_documento          SMALLINT     NOT NULL,
    num_documento           VARCHAR(20)  NOT NULL,
    razon_social            VARCHAR(255),
    nombres                 VARCHAR(100),
    apellido_paterno        VARCHAR(100),
    apellido_materno        VARCHAR(100),
    direccion               VARCHAR(255),
    id_distrito             BIGINT,
    telefono                VARCHAR(20),
    email                   VARCHAR(100),
    es_cliente              BOOLEAN      NOT NULL DEFAULT FALSE,
    es_proveedor            BOOLEAN      NOT NULL DEFAULT FALSE,
    id_convenio             BIGINT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cli_persona_doc UNIQUE (tipo_documento, num_documento),
    CONSTRAINT fk_persona_distrito FOREIGN KEY (id_distrito) REFERENCES gen_distrito (id),
    CONSTRAINT fk_persona_convenio FOREIGN KEY (id_convenio) REFERENCES cli_convenio (id)
);

-- Utilidad: direcciones extra de una persona (delivery futuro).
CREATE TABLE IF NOT EXISTS cli_persona_direccion (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_persona              BIGINT       NOT NULL,
    etiqueta                VARCHAR(50)  NOT NULL,
    direccion               VARCHAR(255) NOT NULL,
    id_distrito             BIGINT,
    referencia              VARCHAR(255),
    es_principal            BOOLEAN      NOT NULL DEFAULT FALSE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_direccion_persona FOREIGN KEY (id_persona) REFERENCES cli_persona (id),
    CONSTRAINT fk_direccion_distrito FOREIGN KEY (id_distrito) REFERENCES gen_distrito (id)
);

-- =============================================================================
-- PRODUCTOS, UNIDADES, CARTA, RECETARIO
-- =============================================================================

-- Utilidad: unidades (kg, g, oz, dash, presa, pote, botella, saco, damajuana).
CREATE TABLE IF NOT EXISTS pro_unidad_medida (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                  VARCHAR(20)  NOT NULL,
    codigo_sunat            VARCHAR(10),
    nombre                  VARCHAR(50)  NOT NULL,
    simbolo                 VARCHAR(10),
    es_fraccionable         BOOLEAN      NOT NULL DEFAULT TRUE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pro_um_codigo UNIQUE (codigo)
);

-- factor: 1 unidad_origen = factor unidades_destino (botella 750 ml = 25.3605 oz)
-- Utilidad: pasar de caja→botella, botella→onzas, kg→g, damajuana→ml.
CREATE TABLE IF NOT EXISTS pro_unidad_conversion (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_unidad_origen        BIGINT       NOT NULL,
    id_unidad_destino       BIGINT       NOT NULL,
    factor                  NUMERIC(18, 8) NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pro_um_conversion UNIQUE (id_unidad_origen, id_unidad_destino),
    CONSTRAINT ck_pro_um_conversion_factor CHECK (factor > 0),
    CONSTRAINT fk_conv_origen FOREIGN KEY (id_unidad_origen) REFERENCES pro_unidad_medida (id),
    CONSTRAINT fk_conv_destino FOREIGN KEY (id_unidad_destino) REFERENCES pro_unidad_medida (id)
);

-- Utilidad: agrupación de carta (entradas, fondos, tragos, etc.).
CREATE TABLE IF NOT EXISTS pro_categoria (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    descripcion             VARCHAR(255),
    es_carta                BOOLEAN      NOT NULL DEFAULT FALSE,
    orden                   INTEGER      NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pro_categoria_codigo UNIQUE (codigo)
);

-- Utilidad: subgrupo dentro de la categoría.
CREATE TABLE IF NOT EXISTS pro_subcategoria (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria            BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    orden                   INTEGER      NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pro_subcategoria UNIQUE (id_categoria, codigo),
    CONSTRAINT fk_subcategoria_categoria FOREIGN KEY (id_categoria) REFERENCES pro_categoria (id)
);

-- tipo_producto (PRODUCTO_TIPO):
--   1 INSUMO_CRUDO
--   2 INSUMO_PROCESADO   ← receta consume esto
--   3 PLATO_CARTA
--   4 PLATO_MENU
--   5 TRAGO
--   6 BEBIDA_UNITARIA    vino botella, gaseosa, agua
--   7 ADICIONAL
-- Utilidad: ítem único: crudo, procesado, plato, menú, trago, botella o adicional.
CREATE TABLE IF NOT EXISTS pro_producto (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_subcategoria         BIGINT       NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    id_estacion             BIGINT,
    id_almacen_stock        BIGINT,
    codigo_interno          VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(150) NOT NULL,
    descripcion             TEXT,
    tipo_producto           SMALLINT     NOT NULL,
    precio_venta            NUMERIC(12, 2) NOT NULL DEFAULT 0,
    costo_receta_calculado  NUMERIC(12, 4) NOT NULL DEFAULT 0,
    afecto_igv              BOOLEAN      NOT NULL DEFAULT TRUE,
    controla_stock          BOOLEAN      NOT NULL DEFAULT FALSE,
    disponible_venta        BOOLEAN      NOT NULL DEFAULT TRUE,
    tiempo_prep_min         INTEGER,
    imagen_url              VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pro_producto_codigo UNIQUE (codigo_interno),
    CONSTRAINT fk_producto_subcategoria FOREIGN KEY (id_subcategoria) REFERENCES pro_subcategoria (id),
    CONSTRAINT fk_producto_unidad FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id),
    CONSTRAINT fk_producto_estacion FOREIGN KEY (id_estacion) REFERENCES gen_estacion (id),
    CONSTRAINT fk_producto_almacen_stock FOREIGN KEY (id_almacen_stock) REFERENCES gen_almacen (id)
);

COMMENT ON COLUMN pro_producto.id_almacen_stock IS
    'Almacén donde vive el stock de este ítem (crudo, cocina o barra).';
COMMENT ON COLUMN pro_producto.controla_stock IS
    'TRUE en crudo, procesado y bebida unitaria. FALSE en plato/trago (se controla por receta).';

-- Cabecera de receta (versionable). Una vigente por producto vendible.
-- Utilidad: receta vigente de un plato o trago (versionable).
CREATE TABLE IF NOT EXISTS pro_receta (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto             BIGINT       NOT NULL,
    version                 INTEGER      NOT NULL DEFAULT 1,
    nombre                  VARCHAR(150),
    rendimiento_porciones   NUMERIC(10, 2) NOT NULL DEFAULT 1,
    vigente                 BOOLEAN      NOT NULL DEFAULT TRUE,
    observacion             TEXT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pro_receta_version UNIQUE (id_producto, version),
    CONSTRAINT fk_receta_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_pro_receta_vigente
    ON pro_receta (id_producto)
    WHERE vigente = TRUE AND estado = 1;

-- Utilidad: insumos y cantidades de la receta (gramos, onzas, presas, potes).
CREATE TABLE IF NOT EXISTS pro_receta_insumo (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_receta               BIGINT       NOT NULL,
    id_producto_insumo      BIGINT       NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    porcentaje_merma        NUMERIC(5, 2) NOT NULL DEFAULT 0,
    es_opcional             BOOLEAN      NOT NULL DEFAULT FALSE,
    grupo_sustitucion       INTEGER,
    orden                   INTEGER      NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_receta_insumo_cant CHECK (cantidad > 0),
    CONSTRAINT fk_receta_insumo_receta FOREIGN KEY (id_receta) REFERENCES pro_receta (id),
    CONSTRAINT fk_receta_insumo_producto FOREIGN KEY (id_producto_insumo) REFERENCES pro_producto (id),
    CONSTRAINT fk_receta_insumo_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

COMMENT ON COLUMN pro_receta_insumo.grupo_sustitucion IS
    'Misma clave = alternativas (pesca del día: toyo / otro pescado). Se descuenta uno al vender.';

-- Utilidad: extras del plato (precio y, si aplica, insumo extra a descontar).
CREATE TABLE IF NOT EXISTS pro_adicional (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto             BIGINT       NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    precio_adicional        NUMERIC(12, 2) NOT NULL DEFAULT 0,
    id_producto_insumo      BIGINT,
    cantidad_insumo         NUMERIC(14, 4) NOT NULL DEFAULT 0,
    id_unidad_medida        BIGINT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_adicional_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_adicional_insumo FOREIGN KEY (id_producto_insumo) REFERENCES pro_producto (id),
    CONSTRAINT fk_adicional_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

-- Menú del día / carta activa (porciones vendibles hoy, PDF/QR posterior)
-- Utilidad: carta/menú de un día (base para PDF o QR).
CREATE TABLE IF NOT EXISTS ven_menu_dia (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    fecha                   DATE         NOT NULL,
    tipo_menu               SMALLINT     NOT NULL DEFAULT 1,
    observacion             VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_menu_dia UNIQUE (id_sucursal, fecha, tipo_menu),
    CONSTRAINT fk_menu_dia_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id)
);

-- Utilidad: platos del día, precio y cuántas porciones se pueden vender.
CREATE TABLE IF NOT EXISTS ven_menu_dia_item (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_menu_dia             BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    precio_venta            NUMERIC(12, 2),
    porciones_disponibles   NUMERIC(14, 4),
    activo                  BOOLEAN      NOT NULL DEFAULT TRUE,
    orden                   INTEGER      NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_menu_dia_item UNIQUE (id_menu_dia, id_producto),
    CONSTRAINT fk_menu_item_menu FOREIGN KEY (id_menu_dia) REFERENCES ven_menu_dia (id),
    CONSTRAINT fk_menu_item_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id)
);

-- =============================================================================
-- INVENTARIO: stock, kardex, salidas de almacén, traslados, ajustes
-- =============================================================================

-- Utilidad: stock actual, mínimo y costo promedio por producto y almacén.
CREATE TABLE IF NOT EXISTS alm_producto_stock (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen              BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    stock_actual            NUMERIC(14, 4) NOT NULL DEFAULT 0,
    stock_minimo            NUMERIC(14, 4) NOT NULL DEFAULT 0,
    stock_reservado         NUMERIC(14, 4) NOT NULL DEFAULT 0,
    costo_promedio          NUMERIC(12, 4) NOT NULL DEFAULT 0,
    alerta_activa           BOOLEAN      NOT NULL DEFAULT FALSE,
    fecha_ultima_alerta     TIMESTAMPTZ,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_alm_stock UNIQUE (id_almacen, id_producto),
    CONSTRAINT ck_alm_stock_no_neg CHECK (stock_actual >= 0),
    CONSTRAINT fk_stock_almacen FOREIGN KEY (id_almacen) REFERENCES gen_almacen (id),
    CONSTRAINT fk_stock_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id)
);

-- tipo_movimiento (KARDEX_TIPO): ver semilla
-- Utilidad: historial de ingresos y salidas (la resta ingreso − venta vive aquí).
CREATE TABLE IF NOT EXISTS alm_kardex (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen              BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    tipo_movimiento         SMALLINT     NOT NULL,
    signo                   SMALLINT     NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    stock_anterior          NUMERIC(14, 4) NOT NULL,
    stock_nuevo             NUMERIC(14, 4) NOT NULL,
    costo_unitario          NUMERIC(12, 4),
    documento_tipo          VARCHAR(40),
    documento_id            BIGINT,
    observacion             TEXT,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_kardex_signo CHECK (signo IN (-1, 1)),
    CONSTRAINT ck_kardex_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_kardex_almacen FOREIGN KEY (id_almacen) REFERENCES gen_almacen (id),
    CONSTRAINT fk_kardex_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_kardex_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

COMMENT ON COLUMN alm_kardex.documento_tipo IS
    'Origen polimórfico: COMPRA, SALIDA, PRODUCCION, PEDIDO_DETALLE, TRASLADO, AJUSTE. documento_id = PK de esa tabla.';

-- Utilidad: aviso de stock bajo para chef y administración.
CREATE TABLE IF NOT EXISTS alm_alerta (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen              BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    stock_al_momento        NUMERIC(14, 4) NOT NULL,
    stock_minimo            NUMERIC(14, 4) NOT NULL,
    vista_chef              BOOLEAN      NOT NULL DEFAULT FALSE,
    vista_admin             BOOLEAN      NOT NULL DEFAULT FALSE,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alerta_almacen FOREIGN KEY (id_almacen) REFERENCES gen_almacen (id),
    CONSTRAINT fk_alerta_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id)
);

-- Requerimiento del chef (crudo). NO entra al recetario.
-- Ej.: "8 patos enteros ~3.2 kg, arroz, arveja, loche, culantro".
-- Utilidad: pedido de crudo del chef (8 patos, arroz, etc.). No entra al recetario.
CREATE TABLE IF NOT EXISTS prod_requerimiento (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    fecha_necesaria         DATE         NOT NULL,
    id_solicitante          BIGINT,
    observacion             TEXT,
    estado_requerimiento    SMALLINT     NOT NULL DEFAULT 1,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_prod_requerimiento_codigo UNIQUE (codigo),
    CONSTRAINT fk_req_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id),
    CONSTRAINT fk_req_solicitante FOREIGN KEY (id_solicitante) REFERENCES auth_usuario (id)
);

-- Utilidad: líneas del requerimiento (producto crudo, cantidad, nota de peso).
CREATE TABLE IF NOT EXISTS prod_requerimiento_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_requerimiento        BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    nota                    VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_req_det_req FOREIGN KEY (id_requerimiento) REFERENCES prod_requerimiento (id),
    CONSTRAINT fk_req_det_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_req_det_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

-- Vale de salida de almacén crudo → cocina/barra (reemplaza el Excel + foto)
-- Utilidad: vale de salida de almacén crudo a cocina o barra (reemplaza el Excel).
CREATE TABLE IF NOT EXISTS alm_salida (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    id_almacen_origen       BIGINT       NOT NULL,
    id_requerimiento        BIGINT,
    codigo                  VARCHAR(50)  NOT NULL,
    destino                 SMALLINT     NOT NULL,
    observacion             TEXT,
    estado_salida           SMALLINT     NOT NULL DEFAULT 1,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_alm_salida_codigo UNIQUE (codigo),
    CONSTRAINT fk_salida_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id),
    CONSTRAINT fk_salida_almacen FOREIGN KEY (id_almacen_origen) REFERENCES gen_almacen (id),
    CONSTRAINT fk_salida_requerimiento FOREIGN KEY (id_requerimiento) REFERENCES prod_requerimiento (id)
);

-- Utilidad: productos y cantidades que salieron del almacén.
CREATE TABLE IF NOT EXISTS alm_salida_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_salida               BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_salida_det_salida FOREIGN KEY (id_salida) REFERENCES alm_salida (id),
    CONSTRAINT fk_salida_det_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_salida_det_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

-- Utilidad: fotos de evidencia cuando administración no está presente.
CREATE TABLE IF NOT EXISTS alm_salida_evidencia (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_salida               BIGINT       NOT NULL,
    archivo_url             VARCHAR(500) NOT NULL,
    observacion             VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_salida_evidencia FOREIGN KEY (id_salida) REFERENCES alm_salida (id)
);

-- Utilidad: mover stock entre almacenes.
CREATE TABLE IF NOT EXISTS alm_traslado (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen_origen       BIGINT       NOT NULL,
    id_almacen_destino      BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    motivo                  VARCHAR(255),
    estado_traslado         SMALLINT     NOT NULL DEFAULT 1,
    observacion             TEXT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_alm_traslado_codigo UNIQUE (codigo),
    CONSTRAINT ck_traslado_distintos CHECK (id_almacen_origen <> id_almacen_destino),
    CONSTRAINT fk_traslado_origen FOREIGN KEY (id_almacen_origen) REFERENCES gen_almacen (id),
    CONSTRAINT fk_traslado_destino FOREIGN KEY (id_almacen_destino) REFERENCES gen_almacen (id)
);

-- Utilidad: detalle de productos del traslado.
CREATE TABLE IF NOT EXISTS alm_traslado_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_traslado             BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_traslado_det_traslado FOREIGN KEY (id_traslado) REFERENCES alm_traslado (id),
    CONSTRAINT fk_traslado_det_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_traslado_det_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

-- Utilidad: conteo / merma / corrección de inventario.
CREATE TABLE IF NOT EXISTS alm_ajuste (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen              BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    motivo                  SMALLINT     NOT NULL,
    observacion             TEXT,
    estado_ajuste           SMALLINT     NOT NULL DEFAULT 1,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_alm_ajuste_codigo UNIQUE (codigo),
    CONSTRAINT fk_ajuste_almacen FOREIGN KEY (id_almacen) REFERENCES gen_almacen (id)
);

-- Utilidad: diferencia entre stock del sistema y lo contado.
CREATE TABLE IF NOT EXISTS alm_ajuste_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ajuste               BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    stock_sistema           NUMERIC(14, 4) NOT NULL,
    stock_contado           NUMERIC(14, 4) NOT NULL,
    diferencia              NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ajuste_det_ajuste FOREIGN KEY (id_ajuste) REFERENCES alm_ajuste (id),
    CONSTRAINT fk_ajuste_det_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_ajuste_det_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

-- =============================================================================
-- PRODUCCIÓN: ingreso de insumos YA porcionados (lo que Inga pide digitalizar)
-- No explota crudo. El chef declara el rendimiento (45 presas, 30 potes, N onzas).
-- =============================================================================

-- Utilidad: ingreso al recetario de lo ya porcionado (45 presas, 30 potes, N onzas).
CREATE TABLE IF NOT EXISTS prod_orden (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    id_almacen_destino      BIGINT       NOT NULL,
    id_requerimiento        BIGINT,
    codigo                  VARCHAR(50)  NOT NULL,
    tipo_produccion         SMALLINT     NOT NULL,
    fecha_produccion        DATE         NOT NULL DEFAULT CURRENT_DATE,
    observacion             TEXT,
    estado_orden            SMALLINT     NOT NULL DEFAULT 1,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_prod_orden_codigo UNIQUE (codigo),
    CONSTRAINT fk_prod_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id),
    CONSTRAINT fk_prod_almacen FOREIGN KEY (id_almacen_destino) REFERENCES gen_almacen (id),
    CONSTRAINT fk_prod_requerimiento FOREIGN KEY (id_requerimiento) REFERENCES prod_requerimiento (id)
);

-- Utilidad: cada insumo procesado que entra a stock de cocina o barra.
CREATE TABLE IF NOT EXISTS prod_orden_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_orden                BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    costo_unitario          NUMERIC(12, 4),
    nota_rendimiento        VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_prod_det_orden FOREIGN KEY (id_orden) REFERENCES prod_orden (id),
    CONSTRAINT fk_prod_det_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_prod_det_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id)
);

COMMENT ON COLUMN prod_orden_detalle.nota_rendimiento IS
    'Texto libre: "De 8 patos enteros". El sistema no calcula la conversión crudo→porción.';

-- =============================================================================
-- COMPRAS
-- =============================================================================

-- Utilidad: compra semanal a proveedor (ingreso a almacén crudo).
CREATE TABLE IF NOT EXISTS com_compra (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_proveedor            BIGINT       NOT NULL,
    id_almacen_destino      BIGINT       NOT NULL,
    id_condicion_pago       BIGINT       NOT NULL,
    tipo_comprobante        SMALLINT     NOT NULL,
    serie_comprobante       VARCHAR(10)  NOT NULL,
    num_comprobante         VARCHAR(20)  NOT NULL,
    fecha_emision           DATE         NOT NULL,
    fecha_recepcion         TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_subtotal          NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_igv               NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_total             NUMERIC(12, 2) NOT NULL DEFAULT 0,
    estado_compra           SMALLINT     NOT NULL DEFAULT 1,
    observacion             TEXT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_com_compra_comp UNIQUE (id_proveedor, tipo_comprobante, serie_comprobante, num_comprobante),
    CONSTRAINT fk_compra_proveedor FOREIGN KEY (id_proveedor) REFERENCES cli_persona (id),
    CONSTRAINT fk_compra_almacen FOREIGN KEY (id_almacen_destino) REFERENCES gen_almacen (id),
    CONSTRAINT fk_compra_condicion FOREIGN KEY (id_condicion_pago) REFERENCES gen_condicion_pago (id)
);

-- Utilidad: líneas de compra; aquí se convierte caja/saco/damajuana a UM de stock.
CREATE TABLE IF NOT EXISTS com_compra_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_compra               BIGINT       NOT NULL,
    id_producto             BIGINT       NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    id_unidad_medida        BIGINT       NOT NULL,
    cantidad_base           NUMERIC(14, 4),
    id_unidad_base          BIGINT,
    costo_unitario          NUMERIC(12, 4) NOT NULL,
    monto_subtotal          NUMERIC(12, 2) NOT NULL DEFAULT 0,
    se_ingresa_kardex       BOOLEAN      NOT NULL DEFAULT TRUE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_compra_det_compra FOREIGN KEY (id_compra) REFERENCES com_compra (id),
    CONSTRAINT fk_compra_det_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_compra_det_um FOREIGN KEY (id_unidad_medida) REFERENCES pro_unidad_medida (id),
    CONSTRAINT fk_compra_det_um_base FOREIGN KEY (id_unidad_base) REFERENCES pro_unidad_medida (id)
);

COMMENT ON COLUMN com_compra_detalle.cantidad_base IS
    'Cantidad ya convertida a UM de stock (caja 12 botellas → N onzas, o se deja en botellas).';

-- =============================================================================
-- CAJA
-- =============================================================================

-- Utilidad: caja física del local.
CREATE TABLE IF NOT EXISTS caj_caja (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_caj_caja UNIQUE (id_sucursal, codigo),
    CONSTRAINT fk_caja_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id)
);

-- Utilidad: turno de cajero (apertura, arqueo, cierre y diferencia).
CREATE TABLE IF NOT EXISTS caj_turno (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_caja                 BIGINT       NOT NULL,
    id_cajero               BIGINT       NOT NULL,
    monto_apertura          NUMERIC(12, 2) NOT NULL DEFAULT 0,
    fecha_apertura          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_cierre_sistema    NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_cierre_declarado  NUMERIC(12, 2),
    monto_diferencia        NUMERIC(12, 2),
    fecha_cierre            TIMESTAMPTZ,
    estado_turno            SMALLINT     NOT NULL DEFAULT 1,
    observacion             VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_turno_caja FOREIGN KEY (id_caja) REFERENCES caj_caja (id),
    CONSTRAINT fk_turno_cajero FOREIGN KEY (id_cajero) REFERENCES auth_usuario (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_caj_turno_abierto
    ON caj_turno (id_caja)
    WHERE estado_turno = 1 AND estado = 1;

-- Utilidad: conteo de billetes y monedas al cerrar.
CREATE TABLE IF NOT EXISTS caj_arqueo_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_turno                BIGINT       NOT NULL,
    denominacion            NUMERIC(12, 2) NOT NULL,
    cantidad                INTEGER      NOT NULL DEFAULT 0,
    monto_subtotal          NUMERIC(12, 2) NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_arqueo_turno FOREIGN KEY (id_turno) REFERENCES caj_turno (id)
);

-- Utilidad: ingresos/egresos de caja que no son una venta (gastos, retiros).
CREATE TABLE IF NOT EXISTS caj_movimiento (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_turno                BIGINT       NOT NULL,
    tipo_movimiento         SMALLINT     NOT NULL,
    monto                   NUMERIC(12, 2) NOT NULL,
    motivo                  VARCHAR(255) NOT NULL,
    id_usuario_autoriza     BIGINT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_caj_mov_monto CHECK (monto > 0),
    CONSTRAINT fk_caj_mov_turno FOREIGN KEY (id_turno) REFERENCES caj_turno (id),
    CONSTRAINT fk_caj_mov_autoriza FOREIGN KEY (id_usuario_autoriza) REFERENCES auth_usuario (id)
);

-- =============================================================================
-- SALÓN, PEDIDOS, COMANDAS, PAGOS, COMPROBANTES
-- =============================================================================

-- Utilidad: zonas del salón (piso, terraza, etc.).
CREATE TABLE IF NOT EXISTS ven_salon (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    codigo                  VARCHAR(50)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    orden                   INTEGER      NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_salon UNIQUE (id_sucursal, codigo),
    CONSTRAINT fk_salon_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id)
);

-- estado_mesa: 1 libre, 2 ocupada, 3 por_cobrar, 4 inhabilitada
-- Utilidad: mesas (libre, ocupada, por cobrar).
CREATE TABLE IF NOT EXISTS ven_mesa (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_salon                BIGINT       NOT NULL,
    codigo                  VARCHAR(20)  NOT NULL,
    capacidad_personas      INTEGER      NOT NULL DEFAULT 2,
    estado_mesa             SMALLINT     NOT NULL DEFAULT 1,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_mesa UNIQUE (id_salon, codigo),
    CONSTRAINT fk_mesa_salon FOREIGN KEY (id_salon) REFERENCES ven_salon (id)
);

-- tipo_pedido: 1 mesa, 2 para_llevar, 3 delivery
-- estado_pedido: 1 abierto, 2 comandado, 3 por_cobrar, 4 pagado, 5 anulado
-- Utilidad: cuenta abierta de la mesa (o para llevar): totales y estado.
CREATE TABLE IF NOT EXISTS ven_pedido (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal             BIGINT       NOT NULL,
    id_mesa                 BIGINT,
    id_mozo                 BIGINT       NOT NULL,
    id_turno                BIGINT,
    id_persona              BIGINT,
    id_convenio             BIGINT,
    tipo_pedido             SMALLINT     NOT NULL DEFAULT 1,
    codigo                  VARCHAR(50)  NOT NULL,
    num_comensales          INTEGER      NOT NULL DEFAULT 1,
    monto_subtotal          NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_descuento         NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_igv               NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_total             NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_pagado            NUMERIC(12, 2) NOT NULL DEFAULT 0,
    estado_pedido           SMALLINT     NOT NULL DEFAULT 1,
    fecha_apertura          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre            TIMESTAMPTZ,
    observacion             TEXT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_pedido_codigo UNIQUE (codigo),
    CONSTRAINT fk_pedido_sucursal FOREIGN KEY (id_sucursal) REFERENCES gen_sucursal (id),
    CONSTRAINT fk_pedido_mesa FOREIGN KEY (id_mesa) REFERENCES ven_mesa (id),
    CONSTRAINT fk_pedido_mozo FOREIGN KEY (id_mozo) REFERENCES auth_usuario (id),
    CONSTRAINT fk_pedido_turno FOREIGN KEY (id_turno) REFERENCES caj_turno (id),
    CONSTRAINT fk_pedido_persona FOREIGN KEY (id_persona) REFERENCES cli_persona (id),
    CONSTRAINT fk_pedido_convenio FOREIGN KEY (id_convenio) REFERENCES cli_convenio (id)
);

-- Comanda = lote enviado a una estación (cocina / barra / caja)
-- Utilidad: lote enviado a una impresora (cocina, barra o caja).
CREATE TABLE IF NOT EXISTS ven_comanda (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido               BIGINT       NOT NULL,
    id_estacion             BIGINT       NOT NULL,
    numero                  INTEGER      NOT NULL,
    estado_comanda          SMALLINT     NOT NULL DEFAULT 1,
    fecha_envio             TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_impresion         TIMESTAMPTZ,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_comanda UNIQUE (id_pedido, id_estacion, numero),
    CONSTRAINT fk_comanda_pedido FOREIGN KEY (id_pedido) REFERENCES ven_pedido (id),
    CONSTRAINT fk_comanda_estacion FOREIGN KEY (id_estacion) REFERENCES gen_estacion (id)
);

-- tipo_linea: 1 normal, 2 cortesia, 3 anulado
-- estado_preparacion: 1 pendiente, 2 enviado, 3 en_prep, 4 listo, 5 entregado, 6 anulado
-- Utilidad: cada plato/trago pedido; al enviarse se descuenta la receta.
CREATE TABLE IF NOT EXISTS ven_pedido_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido               BIGINT       NOT NULL,
    id_comanda              BIGINT,
    id_producto             BIGINT       NOT NULL,
    id_receta               BIGINT,
    cantidad                NUMERIC(14, 4) NOT NULL,
    precio_unitario         NUMERIC(12, 2) NOT NULL,
    monto_descuento         NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_subtotal          NUMERIC(12, 2) NOT NULL,
    tipo_linea              SMALLINT     NOT NULL DEFAULT 1,
    estado_preparacion      SMALLINT     NOT NULL DEFAULT 1,
    observacion             TEXT,
    stock_descontado        BOOLEAN      NOT NULL DEFAULT FALSE,
    id_usuario_autoriza     BIGINT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_pedido_det_cant CHECK (cantidad > 0),
    CONSTRAINT fk_pdet_pedido FOREIGN KEY (id_pedido) REFERENCES ven_pedido (id),
    CONSTRAINT fk_pdet_comanda FOREIGN KEY (id_comanda) REFERENCES ven_comanda (id),
    CONSTRAINT fk_pdet_producto FOREIGN KEY (id_producto) REFERENCES pro_producto (id),
    CONSTRAINT fk_pdet_receta FOREIGN KEY (id_receta) REFERENCES pro_receta (id),
    CONSTRAINT fk_pdet_autoriza FOREIGN KEY (id_usuario_autoriza) REFERENCES auth_usuario (id)
);

-- Utilidad: adicionales elegidos en esa línea (con o sin extra de stock).
CREATE TABLE IF NOT EXISTS ven_pedido_detalle_adicional (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido_detalle       BIGINT       NOT NULL,
    id_adicional            BIGINT       NOT NULL,
    precio_adicional        NUMERIC(12, 2) NOT NULL DEFAULT 0,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pdet_adic_detalle FOREIGN KEY (id_pedido_detalle) REFERENCES ven_pedido_detalle (id),
    CONSTRAINT fk_pdet_adic_adicional FOREIGN KEY (id_adicional) REFERENCES pro_adicional (id)
);

-- tipo_comprobante: 1 boleta, 2 factura, 3 nota_venta, 4 nota_credito
-- tipo_detalle: 1 detallado, 2 por_consumo
-- Utilidad: boleta/factura (detallado o por consumo) e impresión en caja.
CREATE TABLE IF NOT EXISTS ven_comprobante (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido               BIGINT       NOT NULL,
    id_persona              BIGINT,
    id_comprobante_origen   BIGINT,
    tipo_comprobante        SMALLINT     NOT NULL,
    tipo_detalle            SMALLINT     NOT NULL DEFAULT 1,
    receptor_tipo_doc       SMALLINT,
    receptor_num_doc        VARCHAR(20),
    receptor_razon_social   VARCHAR(255),
    serie                   VARCHAR(10)  NOT NULL,
    correlativo             VARCHAR(20)  NOT NULL,
    fecha_emision           TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_gravado           NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_exonerado         NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_igv               NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_total             NUMERIC(12, 2) NOT NULL DEFAULT 0,
    hash_qr                 VARCHAR(255),
    ruta_pdf                VARCHAR(255),
    ruta_xml                VARCHAR(255),
    estado_sunat            SMALLINT     NOT NULL DEFAULT 1,
    sunat_mensaje           TEXT,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ven_comprobante UNIQUE (serie, correlativo, tipo_comprobante),
    CONSTRAINT fk_comp_pedido FOREIGN KEY (id_pedido) REFERENCES ven_pedido (id),
    CONSTRAINT fk_comp_persona FOREIGN KEY (id_persona) REFERENCES cli_persona (id),
    CONSTRAINT fk_comp_origen FOREIGN KEY (id_comprobante_origen) REFERENCES ven_comprobante (id)
);

-- Utilidad: snapshot de ítems del comprobante (SUNAT / PDF).
CREATE TABLE IF NOT EXISTS ven_comprobante_detalle (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_comprobante          BIGINT       NOT NULL,
    id_pedido_detalle       BIGINT,
    descripcion             VARCHAR(255) NOT NULL,
    cantidad                NUMERIC(14, 4) NOT NULL,
    unidad                  VARCHAR(20),
    precio_unitario         NUMERIC(12, 2) NOT NULL,
    monto_total             NUMERIC(12, 2) NOT NULL,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comp_det_comp FOREIGN KEY (id_comprobante) REFERENCES ven_comprobante (id),
    CONSTRAINT fk_comp_det_pdet FOREIGN KEY (id_pedido_detalle) REFERENCES ven_pedido_detalle (id)
);

-- Pago cuelga del PEDIDO (no del comprobante). Permite mixto y crédito sin boleta aún.
-- medio_pago: 1 efectivo, 2 yape, 3 tarjeta, 4 credito
-- Utilidad: cobro del pedido: efectivo, Yape, Visa y/o crédito consorcio (mixto).
CREATE TABLE IF NOT EXISTS ven_pago (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido               BIGINT       NOT NULL,
    id_turno                BIGINT       NOT NULL,
    id_comprobante          BIGINT,
    id_persona              BIGINT,
    id_convenio             BIGINT,
    medio_pago              SMALLINT     NOT NULL,
    monto                   NUMERIC(12, 2) NOT NULL,
    monto_recibido          NUMERIC(12, 2),
    vuelto                  NUMERIC(12, 2) NOT NULL DEFAULT 0,
    num_operacion           VARCHAR(50),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_pago_monto CHECK (monto > 0),
    CONSTRAINT fk_pago_pedido FOREIGN KEY (id_pedido) REFERENCES ven_pedido (id),
    CONSTRAINT fk_pago_turno FOREIGN KEY (id_turno) REFERENCES caj_turno (id),
    CONSTRAINT fk_pago_persona FOREIGN KEY (id_persona) REFERENCES cli_persona (id),
    CONSTRAINT fk_pago_convenio FOREIGN KEY (id_convenio) REFERENCES cli_convenio (id),
    CONSTRAINT fk_pago_comprobante FOREIGN KEY (id_comprobante) REFERENCES ven_comprobante (id)
);

-- =============================================================================
-- KDS
-- =============================================================================

-- Utilidad: ticket en pantalla de cocina/barra (tiempos y estado de preparación).
CREATE TABLE IF NOT EXISTS kds_ticket (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_comanda              BIGINT       NOT NULL,
    id_pedido_detalle       BIGINT       NOT NULL,
    id_estacion             BIGINT       NOT NULL,
    estado_kds              SMALLINT     NOT NULL DEFAULT 1,
    fecha_envio             TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio            TIMESTAMPTZ,
    fecha_listo             TIMESTAMPTZ,
    tiempo_prep_min         INTEGER,
    alerta_tiempo           BOOLEAN      NOT NULL DEFAULT FALSE,
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kds_comanda FOREIGN KEY (id_comanda) REFERENCES ven_comanda (id),
    CONSTRAINT fk_kds_detalle FOREIGN KEY (id_pedido_detalle) REFERENCES ven_pedido_detalle (id),
    CONSTRAINT fk_kds_estacion FOREIGN KEY (id_estacion) REFERENCES gen_estacion (id)
);

-- =============================================================================
-- CXC — crédito consorcio (Billy Reaño / GVR / 4G / etc.)
-- =============================================================================

-- Utilidad: cuenta por cobrar: consumo y pagos a quincena/fin de mes por persona.
CREATE TABLE IF NOT EXISTS cxc_movimiento (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_persona              BIGINT       NOT NULL,
    id_convenio             BIGINT,
    id_pedido               BIGINT,
    id_pago                 BIGINT,
    tipo_movimiento         SMALLINT     NOT NULL,
    monto                   NUMERIC(12, 2) NOT NULL,
    saldo_resultante        NUMERIC(12, 2) NOT NULL,
    anio                    SMALLINT     NOT NULL,
    mes                     SMALLINT     NOT NULL,
    quincena                SMALLINT     NOT NULL,
    observacion             VARCHAR(255),
    estado                  SMALLINT     NOT NULL DEFAULT 1,
    id_usuario_creacion     BIGINT,
    id_usuario_modificacion BIGINT,
    fecha_creacion          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_cxc_tipo CHECK (tipo_movimiento IN (1, 2, 3)),
    CONSTRAINT ck_cxc_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT ck_cxc_quincena CHECK (quincena IN (1, 2)),
    CONSTRAINT fk_cxc_persona FOREIGN KEY (id_persona) REFERENCES cli_persona (id),
    CONSTRAINT fk_cxc_convenio FOREIGN KEY (id_convenio) REFERENCES cli_convenio (id),
    CONSTRAINT fk_cxc_pedido FOREIGN KEY (id_pedido) REFERENCES ven_pedido (id),
    CONSTRAINT fk_cxc_pago FOREIGN KEY (id_pago) REFERENCES ven_pago (id)
);

COMMENT ON COLUMN cxc_movimiento.tipo_movimiento IS '1 cargo (consumo), 2 abono (pago / descuento planilla), 3 ajuste';
COMMENT ON COLUMN cxc_movimiento.quincena IS '1 = días 1-15, 2 = días 16-fin. Reporte a quincena y a fin de mes.';

-- =============================================================================
-- ÍNDICES
-- =============================================================================

CREATE INDEX IF NOT EXISTS ix_auth_sesion_usuario ON auth_sesion (id_usuario, estado);
CREATE INDEX IF NOT EXISTS ix_cli_persona_convenio ON cli_persona (id_convenio) WHERE id_convenio IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_pro_producto_tipo ON pro_producto (tipo_producto, estado);
CREATE INDEX IF NOT EXISTS ix_pro_producto_nombre ON pro_producto (nombre);
CREATE INDEX IF NOT EXISTS ix_receta_insumo_receta ON pro_receta_insumo (id_receta);
CREATE INDEX IF NOT EXISTS ix_alm_kardex_prod_fecha ON alm_kardex (id_producto, id_almacen, fecha_creacion DESC);
CREATE INDEX IF NOT EXISTS ix_alm_kardex_doc ON alm_kardex (documento_tipo, documento_id);
CREATE INDEX IF NOT EXISTS ix_alm_alerta_pendiente ON alm_alerta (fecha_creacion DESC);
CREATE INDEX IF NOT EXISTS ix_ven_mesa_estado ON ven_mesa (estado_mesa) WHERE estado = 1;
CREATE INDEX IF NOT EXISTS ix_ven_pedido_estado ON ven_pedido (id_sucursal, estado_pedido, fecha_apertura DESC);
CREATE INDEX IF NOT EXISTS ix_ven_pedido_persona ON ven_pedido (id_persona, fecha_apertura DESC);
CREATE INDEX IF NOT EXISTS ix_ven_pedido_det_pedido ON ven_pedido_detalle (id_pedido);
CREATE INDEX IF NOT EXISTS ix_ven_pago_pedido ON ven_pago (id_pedido);
CREATE INDEX IF NOT EXISTS ix_ven_pago_medio_fecha ON ven_pago (medio_pago, fecha_creacion);
CREATE INDEX IF NOT EXISTS ix_ven_comp_emision ON ven_comprobante (fecha_emision DESC);
CREATE INDEX IF NOT EXISTS ix_cxc_persona_periodo ON cxc_movimiento (id_persona, anio, mes, quincena);
CREATE INDEX IF NOT EXISTS ix_cxc_convenio_periodo ON cxc_movimiento (id_convenio, anio, mes, quincena);
CREATE INDEX IF NOT EXISTS ix_prod_req_fecha ON prod_requerimiento (id_sucursal, fecha_necesaria DESC);
CREATE INDEX IF NOT EXISTS ix_prod_orden_fecha ON prod_orden (id_sucursal, fecha_produccion DESC);
CREATE INDEX IF NOT EXISTS ix_com_compra_fecha ON com_compra (fecha_emision DESC);
CREATE INDEX IF NOT EXISTS ix_kds_estacion_estado ON kds_ticket (id_estacion, estado_kds);

-- =============================================================================
-- VISTAS DE OPERACIÓN / DASHBOARD
-- =============================================================================

CREATE OR REPLACE VIEW vw_stock_alerta AS
SELECT
    s.id,
    a.id_sucursal,
    a.tipo_almacen,
    a.nombre AS almacen,
    p.codigo_interno,
    p.nombre AS producto,
    p.tipo_producto,
    s.stock_actual,
    s.stock_minimo,
    s.alerta_activa,
    um.simbolo AS um
FROM alm_producto_stock s
JOIN gen_almacen a ON a.id = s.id_almacen
JOIN pro_producto p ON p.id = s.id_producto
JOIN pro_unidad_medida um ON um.id = p.id_unidad_medida
WHERE s.estado = 1
  AND p.controla_stock = TRUE
  AND s.stock_actual <= s.stock_minimo;

CREATE OR REPLACE VIEW vw_cxc_saldo_persona AS
SELECT
    p.id AS id_persona,
    COALESCE(p.nombres || ' ' || p.apellido_paterno, p.razon_social) AS nombre,
    p.id_convenio,
    c.nombre AS convenio,
    COALESCE(SUM(CASE WHEN m.tipo_movimiento = 1 THEN m.monto WHEN m.tipo_movimiento = 2 THEN -m.monto ELSE m.monto END), 0) AS saldo
FROM cli_persona p
LEFT JOIN cli_convenio c ON c.id = p.id_convenio
LEFT JOIN cxc_movimiento m ON m.id_persona = p.id AND m.estado = 1
WHERE p.es_cliente = TRUE
GROUP BY p.id, p.nombres, p.apellido_paterno, p.razon_social, p.id_convenio, c.nombre;

CREATE OR REPLACE VIEW vw_ventas_por_medio AS
SELECT
    date_trunc('day', p.fecha_creacion)::date AS fecha,
    p.medio_pago,
    COUNT(*) AS operaciones,
    SUM(p.monto) AS total
FROM ven_pago p
WHERE p.estado = 1
GROUP BY 1, 2;

CREATE OR REPLACE VIEW vw_platos_rotacion AS
SELECT
    pr.id AS id_producto,
    pr.nombre,
    pr.tipo_producto,
    SUM(d.cantidad) AS unidades_vendidas,
    SUM(d.monto_subtotal) AS monto_vendido
FROM ven_pedido_detalle d
JOIN ven_pedido pe ON pe.id = d.id_pedido
JOIN pro_producto pr ON pr.id = d.id_producto
WHERE d.estado = 1
  AND d.tipo_linea = 1
  AND pe.estado_pedido = 4
GROUP BY pr.id, pr.nombre, pr.tipo_producto;

-- =============================================================================
-- TRIGGERS fecha_modificacion (tablas con esa columna)
-- =============================================================================

DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN
        SELECT c.table_name
        FROM information_schema.columns c
        JOIN information_schema.tables tb
          ON tb.table_schema = c.table_schema
         AND tb.table_name = c.table_name
        WHERE c.table_schema = current_schema()
          AND c.column_name = 'fecha_modificacion'
          AND tb.table_type = 'BASE TABLE'
    LOOP
        -- EXECUTE en PL/pgSQL admite una sola sentencia.
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_mod ON %I', t, t);
        EXECUTE format(
            'CREATE TRIGGER trg_%I_mod
             BEFORE UPDATE ON %I
             FOR EACH ROW
             EXECUTE PROCEDURE fn_set_fecha_modificacion()',
            t, t
        );
    END LOOP;
END;
$$;

-- =============================================================================
-- SEMILLA MÍNIMA (catálogos para arrancar el API)
-- =============================================================================

INSERT INTO gen_lista (codigo, nombre, descripcion) VALUES
    ('PRODUCTO_TIPO', 'Tipo de producto', 'Clasificación de ítems'),
    ('ALMACEN_TIPO', 'Tipo de almacén', 'Crudo vs producción'),
    ('ESTACION_TIPO', 'Tipo de estación', 'Cocina, barra, caja'),
    ('KARDEX_TIPO', 'Tipo movimiento kardex', NULL),
    ('PEDIDO_TIPO', 'Tipo de pedido', NULL),
    ('PEDIDO_ESTADO', 'Estado de pedido', NULL),
    ('MESA_ESTADO', 'Estado de mesa', NULL),
    ('MEDIO_PAGO', 'Medio de pago', NULL),
    ('COMPROBANTE_TIPO', 'Tipo comprobante', NULL),
    ('LINEA_TIPO', 'Tipo línea de pedido', NULL),
    ('PREP_ESTADO', 'Estado preparación', NULL),
    ('SUNAT_ESTADO', 'Estado SUNAT', NULL),
    ('PERSONA_TIPO', 'Tipo persona', NULL),
    ('DOCUMENTO_TIPO', 'Tipo documento identidad', NULL),
    ('SALIDA_DESTINO', 'Destino salida almacén', NULL),
    ('TURNO_ESTADO', 'Estado turno caja', NULL),
    ('CAJA_MOV_TIPO', 'Ingreso/egreso caja', NULL),
    ('PROD_TIPO', 'Tipo orden producción', NULL),
    ('REQ_ESTADO', 'Estado requerimiento cocina', NULL)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO gen_lista_opcion (id_lista, codigo, nombre, valor_entero, orden)
SELECT l.id, v.codigo, v.nombre, v.valor, v.orden
FROM gen_lista l
JOIN (
    VALUES
    ('PRODUCTO_TIPO', 'INSUMO_CRUDO', 'Insumo crudo / almacén', 1, 1),
    ('PRODUCTO_TIPO', 'INSUMO_PROCESADO', 'Insumo procesado / receta', 2, 2),
    ('PRODUCTO_TIPO', 'PLATO_CARTA', 'Plato a la carta', 3, 3),
    ('PRODUCTO_TIPO', 'PLATO_MENU', 'Plato de menú', 4, 4),
    ('PRODUCTO_TIPO', 'TRAGO', 'Trago preparado', 5, 5),
    ('PRODUCTO_TIPO', 'BEBIDA_UNITARIA', 'Bebida por unidad (botella, lata)', 6, 6),
    ('PRODUCTO_TIPO', 'ADICIONAL', 'Adicional', 7, 7),
    ('ALMACEN_TIPO', 'CRUDO', 'Almacén de insumos', 1, 1),
    ('ALMACEN_TIPO', 'PRODUCCION_COCINA', 'Producción cocina', 2, 2),
    ('ALMACEN_TIPO', 'PRODUCCION_BARRA', 'Producción barra', 3, 3),
    ('ESTACION_TIPO', 'COCINA', 'Cocina', 1, 1),
    ('ESTACION_TIPO', 'BARRA', 'Barra', 2, 2),
    ('ESTACION_TIPO', 'CAJA', 'Caja / administración', 3, 3),
    ('KARDEX_TIPO', 'COMPRA', 'Compra / ingreso almacén', 1, 1),
    ('KARDEX_TIPO', 'SALIDA_ALMACEN', 'Salida de almacén crudo', 2, 2),
    ('KARDEX_TIPO', 'PRODUCCION', 'Ingreso por producción', 3, 3),
    ('KARDEX_TIPO', 'VENTA', 'Salida por venta / receta', 4, 4),
    ('KARDEX_TIPO', 'TRASLADO_SALIDA', 'Traslado salida', 5, 5),
    ('KARDEX_TIPO', 'TRASLADO_ENTRADA', 'Traslado entrada', 6, 6),
    ('KARDEX_TIPO', 'AJUSTE_MAS', 'Ajuste positivo', 7, 7),
    ('KARDEX_TIPO', 'AJUSTE_MENOS', 'Ajuste negativo / merma', 8, 8),
    ('KARDEX_TIPO', 'ANULACION_VENTA', 'Reverso por anulación', 9, 9),
    ('PEDIDO_TIPO', 'MESA', 'Atención en mesa', 1, 1),
    ('PEDIDO_TIPO', 'LLEVAR', 'Para llevar', 2, 2),
    ('PEDIDO_TIPO', 'DELIVERY', 'Delivery', 3, 3),
    ('PEDIDO_ESTADO', 'ABIERTO', 'Abierto', 1, 1),
    ('PEDIDO_ESTADO', 'COMANDADO', 'Comandado', 2, 2),
    ('PEDIDO_ESTADO', 'POR_COBRAR', 'Por cobrar', 3, 3),
    ('PEDIDO_ESTADO', 'PAGADO', 'Pagado', 4, 4),
    ('PEDIDO_ESTADO', 'ANULADO', 'Anulado', 5, 5),
    ('MESA_ESTADO', 'LIBRE', 'Libre', 1, 1),
    ('MESA_ESTADO', 'OCUPADA', 'Ocupada', 2, 2),
    ('MESA_ESTADO', 'POR_COBRAR', 'Por cobrar', 3, 3),
    ('MESA_ESTADO', 'INHABILITADA', 'Inhabilitada', 4, 4),
    ('MEDIO_PAGO', 'EFECTIVO', 'Efectivo', 1, 1),
    ('MEDIO_PAGO', 'YAPE', 'Yape', 2, 2),
    ('MEDIO_PAGO', 'TARJETA', 'Visa / tarjeta', 3, 3),
    ('MEDIO_PAGO', 'CREDITO', 'Crédito / descuento consorcio', 4, 4),
    ('COMPROBANTE_TIPO', 'BOLETA', 'Boleta', 1, 1),
    ('COMPROBANTE_TIPO', 'FACTURA', 'Factura', 2, 2),
    ('COMPROBANTE_TIPO', 'NOTA_VENTA', 'Nota de venta', 3, 3),
    ('COMPROBANTE_TIPO', 'NOTA_CREDITO', 'Nota de crédito', 4, 4),
    ('LINEA_TIPO', 'NORMAL', 'Normal', 1, 1),
    ('LINEA_TIPO', 'CORTESIA', 'Cortesía', 2, 2),
    ('LINEA_TIPO', 'ANULADO', 'Anulado', 3, 3),
    ('PREP_ESTADO', 'PENDIENTE', 'Pendiente', 1, 1),
    ('PREP_ESTADO', 'ENVIADO', 'Enviado', 2, 2),
    ('PREP_ESTADO', 'EN_PREP', 'En preparación', 3, 3),
    ('PREP_ESTADO', 'LISTO', 'Listo', 4, 4),
    ('PREP_ESTADO', 'ENTREGADO', 'Entregado', 5, 5),
    ('PREP_ESTADO', 'ANULADO', 'Anulado', 6, 6),
    ('SUNAT_ESTADO', 'PENDIENTE', 'Pendiente', 1, 1),
    ('SUNAT_ESTADO', 'ACEPTADO', 'Aceptado', 2, 2),
    ('SUNAT_ESTADO', 'RECHAZADO', 'Rechazado', 3, 3),
    ('SUNAT_ESTADO', 'ANULADO', 'Anulado', 4, 4),
    ('PERSONA_TIPO', 'NATURAL', 'Persona natural', 1, 1),
    ('PERSONA_TIPO', 'JURIDICA', 'Persona jurídica', 2, 2),
    ('DOCUMENTO_TIPO', 'DNI', 'DNI', 1, 1),
    ('DOCUMENTO_TIPO', 'RUC', 'RUC', 6, 2),
    ('DOCUMENTO_TIPO', 'CE', 'Carné extranjería', 4, 3),
    ('SALIDA_DESTINO', 'COCINA', 'Cocina', 1, 1),
    ('SALIDA_DESTINO', 'BARRA', 'Barra', 2, 2),
    ('TURNO_ESTADO', 'ABIERTO', 'Abierto', 1, 1),
    ('TURNO_ESTADO', 'CERRADO', 'Cerrado', 2, 2),
    ('CAJA_MOV_TIPO', 'INGRESO', 'Ingreso', 1, 1),
    ('CAJA_MOV_TIPO', 'EGRESO', 'Egreso', 2, 2),
    ('PROD_TIPO', 'COCINA', 'Producción cocina', 1, 1),
    ('PROD_TIPO', 'BARRA', 'Producción barra (onzas)', 2, 2),
    ('REQ_ESTADO', 'SOLICITADO', 'Solicitado', 1, 1),
    ('REQ_ESTADO', 'ATENDIDO', 'Atendido (salida de almacén)', 2, 2),
    ('REQ_ESTADO', 'PRODUCIDO', 'Producido (ingreso recetario)', 3, 3)
) AS v(lista, codigo, nombre, valor, orden) ON v.lista = l.codigo
ON CONFLICT (id_lista, codigo) DO NOTHING;

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito) VALUES
    ('CONTADO', 'Contado', 0),
    ('CREDITO_15', 'Crédito quincenal', 15),
    ('CREDITO_30', 'Crédito 30 días', 30)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO cli_convenio (codigo, nombre, id_condicion_pago, limite_credito, corte_quincenal)
SELECT v.codigo, v.nombre, c.id, 0, TRUE
FROM (VALUES
    ('GVR', 'GVR'),
    ('4G', '4G'),
    ('APUSALUD', 'ApuSalud'),
    ('JURISCONTA', 'Jurisconta')
) AS v(codigo, nombre)
JOIN gen_condicion_pago c ON c.codigo = 'CREDITO_15'
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO pro_unidad_medida (codigo, codigo_sunat, nombre, simbolo, es_fraccionable) VALUES
    ('NIU', 'NIU', 'Unidad', 'und', FALSE),
    ('KG',  'KGM', 'Kilogramo', 'kg', TRUE),
    ('G',   'GRM', 'Gramo', 'g', TRUE),
    ('L',   'LTR', 'Litro', 'L', TRUE),
    ('ML',  'MLT', 'Mililitro', 'ml', TRUE),
    ('OZ',  NULL,  'Onza', 'oz', TRUE),
    ('DASH', NULL, 'Dash (~0.5 oz)', 'dash', TRUE),
    ('PORC', NULL, 'Porción', 'pzc', FALSE),
    ('PRESA', NULL, 'Presa', 'presa', FALSE),
    ('POTE', NULL, 'Pote / porción salsa', 'pote', FALSE),
    ('BOT', NULL,  'Botella', 'bot', FALSE),
    ('CAJA', NULL, 'Caja', 'caja', FALSE),
    ('SACO', NULL, 'Saco', 'saco', FALSE),
    ('PLANCHA', NULL, 'Plancha', 'plancha', FALSE),
    ('DAMA', NULL, 'Damajuana 3.8 L', 'dama', FALSE)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO pro_unidad_conversion (id_unidad_origen, id_unidad_destino, factor)
SELECT o.id, d.id, v.factor
FROM (VALUES
    ('KG', 'G', 1000),
    ('L', 'ML', 1000),
    ('BOT', 'ML', 750),
    ('BOT', 'OZ', 25.3605),
    ('OZ', 'ML', 29.5735),
    ('DASH', 'OZ', 0.5),
    ('CAJA', 'BOT', 12),
    ('DAMA', 'ML', 3800),
    ('DAMA', 'OZ', 128.494)
) AS v(origen, destino, factor)
JOIN pro_unidad_medida o ON o.codigo = v.origen
JOIN pro_unidad_medida d ON d.codigo = v.destino
ON CONFLICT (id_unidad_origen, id_unidad_destino) DO NOTHING;

INSERT INTO auth_rol (codigo, nombre, descripcion) VALUES
    ('ADMIN', 'Administración', 'Control total, reportes, crédito, almacén'),
    ('CAJERO', 'Caja', 'Cobro, comprobantes, turno de caja'),
    ('MOZO', 'Mozo', 'Toma de pedidos y comandas'),
    ('CHEF', 'Cocina', 'KDS, producción, alertas de receta'),
    ('BARMAN', 'Barra', 'Comandas de tragos y stock de onzas')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO gen_pais (nombre, codigo_iso)
VALUES ('Perú', 'PE')
ON CONFLICT (codigo_iso) DO NOTHING;

-- =============================================================================
-- FIN
-- =============================================================================
