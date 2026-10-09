# Tipos de producto

El catálogo operativo vive en `pro_tipo_producto`. `pro_producto.tipo_producto` conserva su nombre y tipo SMALLINT, y referencia el ID del catálogo. Los indicadores son booleanos independientes. `controla_stock` sigue siendo una propiedad del producto; si está activo, exige almacén.

## Aplicación manual

No se ejecutó SQL contra tu base. La carga de tipos históricos y eliminación de PRODUCTO_TIPO de `gen_lista`/`gen_lista_opcion` quedan a tu cargo.

1. Aplicar `database_sql/migraciones/08_tipos_producto_estructura.sql` para crear la tabla vacía y su FK pendiente de validación.
2. Cargar manualmente los tipos, conservando como `id` el antiguo `valor_entero` (no el ID de `gen_lista_opcion`). Asignar explícitamente los cuatro indicadores de cada tipo. No se incluyen semillas ni una copia automática.
3. Ajustar la secuencia después de insertar IDs explícitos:

```sql
SELECT setval(pg_get_serial_sequence('pro_tipo_producto', 'id'),
  COALESCE((SELECT MAX(id) FROM pro_tipo_producto), 1),
  EXISTS (SELECT 1 FROM pro_tipo_producto));
ALTER TABLE pro_producto VALIDATE CONSTRAINT fk_pro_producto_tipo;
```

4. Aplicar `database_sql/instalar_tipos_producto.sql` con psql (o ejecutar sus archivos referenciados en ese orden desde tu editor SQL). Requiere el módulo de inventario ya instalado. El instalador no copia ni borra registros.
5. Desplegar backend y frontend conjuntamente. Comprobar los tipos y productos; después retirar manualmente la antigua lista genérica cuando no haya clientes antiguos utilizándola.

La FK `NOT VALID` permite cargar los tipos históricos antes de validar los productos existentes; sí se aplica a nuevas escrituras. Evitar operaciones de productos durante estos pasos.

## API y reglas

- `GET /tipos-producto`: catálogo activo para usuarios autenticados, incluidos quienes operan pedidos.
- `POST /tipos-producto`: requiere `PRODUCTOS_CREAR`; recibe nombre y los cuatro booleanos. La auditoría proviene de la sesión. Rechaza nombres vacíos o duplicados sin distinguir mayúsculas ni espacios exteriores.
- Los endpoints siguen el envoltorio global de respuestas de la API.
- `permite_venta=false`: precio cero y fuera de carta. Tampoco puede activarse mediante el toggle ni consumirse en pedidos.
- `requiere_receta=true`: permite gestionar receta desde Productos y la exige al consumir un pedido. No exige una receta antes de crear el producto, ya que se configura después en Preparaciones.
- `requiere_estacion=true`: estación obligatoria al crear o editar. Al pasar a un tipo que no la requiere se borra la estación.
- `permite_stock_inicial=false`: impide saldo y costo inicial. No desactiva el control de stock. Las compras de productos con receta y sin stock inicial siguen entrando mediante preparación.
- Los valores ocultos se limpian en frontend y las reglas se aplican también en SQL. La edición resuelve las reglas usando los datos actuales más los campos recibidos.

La clasificación específica de insumos procesados (tipo 2) en el módulo de recetas de insumos conserva su significado; los cuatro indicadores no definen una nueva clasificación de insumos.

## Verificación

- Backend: `npm run build` y `npm test -- --runInBand src/modules/tipos-producto/dto/tipos-producto.dto.spec.ts`.
- Frontend: `npx tsc --noEmit` y `node --test test/productos/producto-reglas.test.mjs`.
- Integración: `npm run test:inventario:sql` contra el clúster local temporal descrito en `docs/pedidos.md`. Crea y elimina su propia base de pruebas, sin leer `.env`. Incluye tipos de prueba y utiliza un tipo recién creado en pedidos y producción. No aplica ninguna migración a la base del usuario.
