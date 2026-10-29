-- Multiempresa, fase 3: catálogos por empresa (opción A). Re-ejecutable.
--
-- Catálogos que hoy son compartidos por todas las empresas pasan a pertenecer a
-- una sola empresa: productos, categorías, subcategorías, recetas, adicionales,
-- tipos de producto, clientes/proveedores, convenios, compras, CxP/CxC,
-- categorías de gasto, insumos de gastos diarios, roles y QZ/notificaciones.
-- El stock sigue por almacén/sucursal y no cambia.
BEGIN;

-- ---------------------------------------------------------------------------
-- Helper: empresa de un usuario (su trabajador)
-- ---------------------------------------------------------------------------
-- (se usa inline en los backfills)

-- ---------------------------------------------------------------------------
-- auth_rol: roles propios de cada empresa (NULL = global del sistema)
-- ---------------------------------------------------------------------------
ALTER TABLE auth_rol ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE auth_rol r
SET id_empresa = NULL
WHERE r.id_empresa IS NULL;
DO $mig$ BEGIN
    ALTER TABLE auth_rol
        ADD CONSTRAINT fk_auth_rol_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
ALTER TABLE auth_rol DROP CONSTRAINT IF EXISTS uq_auth_rol_codigo;
DO $mig$ BEGIN
    ALTER TABLE auth_rol
        ADD CONSTRAINT uq_auth_rol_empresa_codigo
        UNIQUE (id_empresa, codigo);
EXCEPTION WHEN duplicate_object THEN NULL;
          WHEN duplicate_table THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- gen_qz_configuracion: certificado por empresa (se mantiene fila única global
-- como respaldo; la columna permite filtrar por empresa cuando se multiplique)
-- ---------------------------------------------------------------------------
ALTER TABLE gen_qz_configuracion ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE gen_qz_configuracion
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE gen_qz_configuracion
        ADD CONSTRAINT fk_gen_qz_configuracion_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- cli_convenio
-- ---------------------------------------------------------------------------
ALTER TABLE cli_convenio ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE cli_convenio c
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = c.id_usuario_creacion),
    (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
)
WHERE c.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE cli_convenio
        ADD CONSTRAINT fk_cli_convenio_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM cli_convenio WHERE id_empresa IS NULL) THEN
        ALTER TABLE cli_convenio ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

-- ---------------------------------------------------------------------------
-- cli_persona (clientes y proveedores)
-- ---------------------------------------------------------------------------
ALTER TABLE cli_persona ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE cli_persona p
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = p.id_usuario_creacion),
    (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
)
WHERE p.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
-- Respaldo: si hay varias empresas y sin creador, queda NULL (se asigna manualmente).
DO $mig$ BEGIN
    ALTER TABLE cli_persona
        ADD CONSTRAINT fk_cli_persona_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
ALTER TABLE cli_persona DROP CONSTRAINT IF EXISTS uq_cli_persona_doc;
DO $mig$ BEGIN
    ALTER TABLE cli_persona
        ADD CONSTRAINT uq_cli_persona_empresa_doc
        UNIQUE (id_empresa, tipo_documento, num_documento);
EXCEPTION WHEN duplicate_object THEN NULL;
          WHEN duplicate_table THEN NULL;
END $mig$;

-- Cliente genérico por empresa (boletas sin DNI y notas de venta).
DO $mig$ DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id FROM gen_empresa LOOP
        IF NOT EXISTS (
            SELECT 1 FROM cli_persona
            WHERE id_empresa = r.id AND tipo_documento = 1 AND num_documento = '00000000'
        ) THEN
            INSERT INTO cli_persona (id_empresa, tipo_persona, tipo_documento, num_documento, razon_social, nombres, es_cliente, estado)
            VALUES (r.id, 1, 1, '00000000', 'CLIENTES VARIOS', 'CLIENTES VARIOS', TRUE, 1);
        END IF;
    END LOOP;
END $mig$;

-- ---------------------------------------------------------------------------
-- pro_categoria
-- ---------------------------------------------------------------------------
ALTER TABLE pro_categoria ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE pro_categoria c
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = c.id_usuario_creacion),
    (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
)
WHERE c.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE pro_categoria
        ADD CONSTRAINT fk_pro_categoria_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pro_categoria WHERE id_empresa IS NULL) THEN
        ALTER TABLE pro_categoria ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

-- ---------------------------------------------------------------------------
-- pro_subcategoria
-- ---------------------------------------------------------------------------
ALTER TABLE pro_subcategoria ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE pro_subcategoria s
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = s.id_usuario_creacion),
    c.id_empresa
)
FROM pro_categoria c
WHERE c.id = s.id_categoria
  AND s.id_empresa IS NULL;
UPDATE pro_subcategoria s
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE s.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE pro_subcategoria
        ADD CONSTRAINT fk_pro_subcategoria_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pro_subcategoria WHERE id_empresa IS NULL) THEN
        ALTER TABLE pro_subcategoria ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

-- ---------------------------------------------------------------------------
-- pro_tipo_producto
-- ---------------------------------------------------------------------------
ALTER TABLE pro_tipo_producto ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE pro_tipo_producto t
SET id_empresa = COALESCE(
    (SELECT tt.id_empresa
       FROM auth_usuario u JOIN pla_trabajador tt ON tt.id = u.id_trabajador
      WHERE u.id = t.id_usuario_creacion),
    (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
)
WHERE t.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE pro_tipo_producto
        ADD CONSTRAINT fk_pro_tipo_producto_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- pro_producto
-- ---------------------------------------------------------------------------
ALTER TABLE pro_producto ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE pro_producto p
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = p.id_usuario_creacion),
    sc.id_empresa
)
FROM pro_subcategoria sc
WHERE sc.id = p.id_subcategoria
  AND p.id_empresa IS NULL;
UPDATE pro_producto p
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE p.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE pro_producto
        ADD CONSTRAINT fk_pro_producto_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id_empresa IS NULL) THEN
        ALTER TABLE pro_producto ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

-- ---------------------------------------------------------------------------
-- pro_receta
-- ---------------------------------------------------------------------------
ALTER TABLE pro_receta ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE pro_receta r
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = r.id_usuario_creacion),
    p.id_empresa
)
FROM pro_producto p
WHERE p.id = r.id_producto
  AND r.id_empresa IS NULL;
UPDATE pro_receta r
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE r.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE pro_receta
        ADD CONSTRAINT fk_pro_receta_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pro_receta WHERE id_empresa IS NULL) THEN
        ALTER TABLE pro_receta ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

-- ---------------------------------------------------------------------------
-- pro_receta_insumo (hereda de la receta)
-- ---------------------------------------------------------------------------
ALTER TABLE pro_receta_insumo ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE pro_receta_insumo ri
SET id_empresa = r.id_empresa
FROM pro_receta r
WHERE r.id = ri.id_receta
  AND ri.id_empresa IS NULL;
DO $mig$ BEGIN
    ALTER TABLE pro_receta_insumo
        ADD CONSTRAINT fk_pro_receta_insumo_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- pro_adicional
-- ---------------------------------------------------------------------------
ALTER TABLE pro_adicional ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE pro_adicional a
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = a.id_usuario_creacion),
    p.id_empresa
)
FROM pro_producto p
WHERE p.id = a.id_producto
  AND a.id_empresa IS NULL;
UPDATE pro_adicional a
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE a.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE pro_adicional
        ADD CONSTRAINT fk_pro_adicional_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pro_adicional WHERE id_empresa IS NULL) THEN
        ALTER TABLE pro_adicional ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

-- ---------------------------------------------------------------------------
-- com_compra
-- ---------------------------------------------------------------------------
ALTER TABLE com_compra ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE com_compra c
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = c.id_usuario_creacion),
    s.id_empresa
)
FROM gen_almacen a
JOIN gen_sucursal s ON s.id = a.id_sucursal
WHERE a.id = c.id_almacen_destino
  AND c.id_empresa IS NULL;
UPDATE com_compra c
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE c.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE com_compra
        ADD CONSTRAINT fk_com_compra_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
DO $mig$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM com_compra WHERE id_empresa IS NULL) THEN
        ALTER TABLE com_compra ALTER COLUMN id_empresa SET NOT NULL;
    END IF;
END $mig$;

-- ---------------------------------------------------------------------------
-- cxp_movimiento
-- ---------------------------------------------------------------------------
ALTER TABLE cxp_movimiento ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE cxp_movimiento m
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = m.id_usuario_creacion),
    p.id_empresa
)
FROM cli_persona p
WHERE p.id = m.id_persona
  AND m.id_empresa IS NULL;
UPDATE cxp_movimiento m
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE m.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE cxp_movimiento
        ADD CONSTRAINT fk_cxp_movimiento_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- cxc_movimiento (por consistencia)
-- ---------------------------------------------------------------------------
ALTER TABLE cxc_movimiento ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE cxc_movimiento m
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = m.id_usuario_creacion),
    p.id_empresa
)
FROM cli_persona p
WHERE p.id = m.id_persona
  AND m.id_empresa IS NULL;
UPDATE cxc_movimiento m
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE m.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE cxc_movimiento
        ADD CONSTRAINT fk_cxc_movimiento_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- gad_categoria
-- ---------------------------------------------------------------------------
ALTER TABLE gad_categoria ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE gad_categoria g
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = g.id_usuario_creacion),
    (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
)
WHERE g.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE gad_categoria
        ADD CONSTRAINT fk_gad_categoria_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- gdo_categoria
-- ---------------------------------------------------------------------------
ALTER TABLE gdo_categoria ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE gdo_categoria g
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = g.id_usuario_creacion),
    (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
)
WHERE g.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE gdo_categoria
        ADD CONSTRAINT fk_gdo_categoria_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
ALTER TABLE gdo_categoria DROP CONSTRAINT IF EXISTS uq_gdo_categoria_codigo;
DO $mig$ BEGIN
    ALTER TABLE gdo_categoria
        ADD CONSTRAINT uq_gdo_categoria_empresa_codigo
        UNIQUE (id_empresa, codigo);
EXCEPTION WHEN duplicate_object THEN NULL;
          WHEN duplicate_table THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- gdo_insumo
-- ---------------------------------------------------------------------------
ALTER TABLE gdo_insumo ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
UPDATE gdo_insumo i
SET id_empresa = COALESCE(
    (SELECT t.id_empresa
       FROM auth_usuario u JOIN pla_trabajador t ON t.id = u.id_trabajador
      WHERE u.id = i.id_usuario_creacion),
    c.id_empresa
)
FROM gdo_categoria c
WHERE c.id = i.id_categoria
  AND i.id_empresa IS NULL;
UPDATE gdo_insumo i
SET id_empresa = (SELECT e.id FROM gen_empresa e WHERE e.estado = 1 ORDER BY e.id LIMIT 1)
WHERE i.id_empresa IS NULL
  AND (SELECT COUNT(*) FROM gen_empresa e WHERE e.estado = 1) = 1;
DO $mig$ BEGIN
    ALTER TABLE gdo_insumo
        ADD CONSTRAINT fk_gdo_insumo_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;
ALTER TABLE gdo_insumo DROP CONSTRAINT IF EXISTS uq_gdo_insumo_nombre;
DO $mig$ BEGIN
    ALTER TABLE gdo_insumo
        ADD CONSTRAINT uq_gdo_insumo_empresa_nombre
        UNIQUE (id_empresa, id_categoria, nombre);
EXCEPTION WHEN duplicate_object THEN NULL;
          WHEN duplicate_table THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- notificaciones
-- ---------------------------------------------------------------------------
ALTER TABLE notificaciones ADD COLUMN IF NOT EXISTS id_empresa BIGINT;
DO $mig$ BEGIN
    ALTER TABLE notificaciones
        ADD CONSTRAINT fk_notificaciones_empresa
        FOREIGN KEY (id_empresa) REFERENCES gen_empresa (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $mig$;

-- ---------------------------------------------------------------------------
-- Vistas de saldos: exponen id_empresa
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_cxc_saldo_persona;
CREATE VIEW vw_cxc_saldo_persona AS
SELECT
    p.id AS id_persona,
    p.id_empresa,
    COALESCE(
        NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
        p.razon_social
    ) AS nombre,
    p.num_documento,
    p.id_convenio,
    c.nombre AS convenio,
    c.limite_credito,
    COALESCE(SUM(
        CASE
            WHEN m.tipo_movimiento = 1 THEN m.monto
            WHEN m.tipo_movimiento = 2 THEN -m.monto
            ELSE m.monto
        END
    ), 0) AS saldo,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0) AS total_cargos,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0) AS total_abonos,
    MAX(m.fecha_creacion) FILTER (WHERE m.tipo_movimiento = 2) AS ultimo_abono
FROM cli_persona p
LEFT JOIN cli_convenio c ON c.id = p.id_convenio
LEFT JOIN cxc_movimiento m ON m.id_persona = p.id AND m.estado = 1
WHERE p.es_cliente = TRUE AND p.estado = 1
GROUP BY p.id, p.id_empresa, p.nombres, p.apellido_paterno, p.razon_social, p.num_documento,
         p.id_convenio, c.nombre, c.limite_credito;

-- ---------------------------------------------------------------------------
-- Vista de saldos CxP: expone id_empresa
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_cxp_saldo_proveedor;
CREATE VIEW vw_cxp_saldo_proveedor AS
SELECT
    p.id AS id_persona,
    p.id_empresa,
    COALESCE(
        NULLIF(TRIM(COALESCE(p.nombres, '') || ' ' || COALESCE(p.apellido_paterno, '')), ''),
        p.razon_social
    ) AS nombre,
    p.num_documento,
    COALESCE(SUM(
        CASE
            WHEN m.tipo_movimiento = 1 THEN m.monto
            WHEN m.tipo_movimiento = 2 THEN -m.monto
            ELSE m.monto
        END
    ), 0) AS saldo,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 1), 0) AS total_cargos,
    COALESCE(SUM(m.monto) FILTER (WHERE m.tipo_movimiento = 2), 0) AS total_abonos,
    MAX(m.fecha_movimiento) FILTER (WHERE m.tipo_movimiento = 2) AS ultimo_abono
FROM cli_persona p
LEFT JOIN cxp_movimiento m ON m.id_persona = p.id AND m.estado = 1
WHERE p.es_proveedor = TRUE AND p.estado = 1
GROUP BY p.id, p.id_empresa, p.nombres, p.apellido_paterno, p.razon_social, p.num_documento;

COMMIT;

-- ---------------------------------------------------------------------------
-- Funciones (catálogo Productos)
-- ---------------------------------------------------------------------------
\ir ../funciones/productos/categoria-producto/pro_listar_categorias.sql
\ir ../funciones/productos/categoria-producto/pro_obtener_categoria.sql
\ir ../funciones/productos/categoria-producto/pro_crear_categoria.sql
\ir ../funciones/productos/categoria-producto/pro_actualizar_categoria.sql
\ir ../funciones/productos/categoria-producto/pro_eliminar_categoria.sql
\ir ../funciones/productos/categoria-producto/pro_activar_categoria.sql

\ir ../funciones/productos/sub-categorias/pro_listar_sub_categorias.sql
\ir ../funciones/productos/sub-categorias/pro_obtener_sub_categoria.sql
\ir ../funciones/productos/sub-categorias/pro_crear_sub_categoria.sql
\ir ../funciones/productos/sub-categorias/pro_actualizar_sub_categoria.sql
\ir ../funciones/productos/sub-categorias/pro_eliminar_sub_categoria.sql
\ir ../funciones/productos/sub-categorias/pro_activar_sub_categoria.sql

\ir ../funciones/productos/tipos-producto/pro_listar_tipos_producto.sql
\ir ../funciones/productos/tipos-producto/pro_crear_tipo_producto.sql

\ir ../funciones/productos/productos/pro_listar_productos.sql
\ir ../funciones/productos/productos/pro_obtener_producto.sql
\ir ../funciones/productos/productos/pro_crear_producto.sql
\ir ../funciones/productos/productos/pro_actualizar_producto.sql
\ir ../funciones/productos/productos/pro_eliminar_producto.sql
\ir ../funciones/productos/productos/pro_activar_producto.sql
\ir ../funciones/productos/productos/pro_toggle_disponibilidad_producto.sql
\ir ../funciones/productos/productos/pro_crear_producto_stock.sql

\ir ../funciones/productos/producto-adicional/pro_listar_adicionales_producto.sql
\ir ../funciones/productos/producto-adicional/pro_obtener_adicional.sql
\ir ../funciones/productos/producto-adicional/pro_crear_adicional.sql
\ir ../funciones/productos/producto-adicional/pro_actualizar_adicional.sql
\ir ../funciones/productos/producto-adicional/pro_eliminar_adicional.sql

\ir ../funciones/productos/productos-recetas-insumos/pro_listar_recetas_producto.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_obtener_receta.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_crear_receta.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_eliminar_receta.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_listar_insumos_procesados.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_guardar_receta_insumo.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_eliminar_receta_insumo.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_explotar_receta.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_costo_unitario_insumo.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_recalcular_costo_receta.sql
\ir ../funciones/productos/productos-recetas-insumos/pro_receta_vigente.sql
