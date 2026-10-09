# Inventario, producción y entrega

## Instalación

En una base existente, ejecutar con psql:

```sh
psql -X -v ON_ERROR_STOP=1 -d nombre_base -f database_sql/instalar_inventario.sql
```

El instalador ejecuta las migraciones (`04_inventario_unificado.sql` y `05_reserva_insumos.sql`) y reemplaza las funciones de pedidos dentro de una sola transacción. Las líneas comandadas antes de `05` no tienen ingredientes apartados: se preparan como antes. `instalar_pedidos.sql` delega en el mismo instalador. Para una base vacía, instalar primero `database_sql/database.sql` (o su versión reejecutable), y después este instalador. El esquema base por sí solo no instala las funciones operativas.

No ejecutar el esquema base como migración de una base anterior: `CREATE TABLE IF NOT EXISTS` no actualiza sus columnas. La migración de inventario es `04_inventario_unificado.sql`.

Antes de migrar una base anterior deben cerrarse los pedidos activos cuyo stock ya fue descontado y resolverse las reservas del flujo anterior. La migración falla y revierte si encuentra esos casos. También exige autores reales en `alm_producto_stock`, `alm_kardex`, `prod_orden` y `prod_orden_detalle`; si hay `id_usuario_creacion` nulos deben reconciliarse previamente, sin asignar un usuario ficticio. No se cambian automáticamente los productos existentes: configurar `controla_stock=true` y `id_almacen_stock` en los platos terminados antes de usarlos en el nuevo flujo.

Las tablas anteriores de kardex, alertas, salidas, traslados, ajustes y evidencias se conservan íntegramente en `historial_almacen`. El kardex se copia al modelo nuevo sin modificar saldos. Sus movimientos se identifican con `LEGACY-<id>` y motivo `CORRECCION_REGISTRO`; el detalle guarda el tipo numérico original, que también se conserva en la tabla archivada. Los documentos antiguos permanecen consultables en ese esquema, no se reinterpretan como nuevas operaciones. No se borran datos.

## Modelo

### Organización de archivos

El backend sigue `controllers/`, `logic/`, `models/` y `dto/`. El controller delega en logic; model accede a PostgreSQL mediante `callFunctionJson`, sin consultas SQL embebidas.

Cada función SQL tiene su propio archivo con el mismo nombre: las funciones `alm_*` están en `database_sql/funciones/inventario/`, las `ven_*` en `database_sql/funciones/pedidos/` y `prod_preparar` en `database_sql/funciones/produccion/`. Los triggers permanecen junto a su función correspondiente. `instalar_inventario.sql` carga explícitamente todos los archivos.

- `alm_producto_stock`: existencias, mínimo, costo promedio y reserva total por almacén/producto. Se mantiene `estado` para compatibilidad con los catálogos actuales.
- `alm_movimiento`: cabecera; estados 1 borrador, 2 confirmado y 3 cancelado. El usuario de la confirmación queda como último modificador de la cabecera inmutable.
- `alm_movimiento_detalle`: afectaciones de stock, con auditoría propia. No incluye `stock_contado` ni `id_detalle_origen`.
- `vw_alm_kardex`: solo movimientos confirmados. Ordenar por `fecha_confirmacion,id` para seguir el orden aplicado a las existencias.
- `vw_stock_alerta`: `stock_actual <= stock_minimo`, calculado sin tabla de avisos.

Todas las tablas nuevas llevan `id_usuario_creacion NOT NULL`, `id_usuario_modificacion`, `fecha_creacion` y `fecha_modificacion`. No se añade `id_usuario_confirmacion`. Las tablas de producción existentes conservan esos cuatro campos y pasan a exigir creador.

Tipos y motivos referencian `gen_lista_opcion.id`. Las listas son `ALM_TIPO_MOVIMIENTO` y `ALM_MOTIVO_MOVIMIENTO`. `valor_entero` del tipo es 1 entrada, 2 salida, 3 traslado y 4 ajuste; en los motivos indica el tipo permitido. No usar IDs fijos en clientes. Para producción hay dos motivos: `PRODUCCION_CONSUMO` (salida) y `PRODUCCION_ENTRADA` (entrada).

Los traslados tienen exactamente dos líneas por producto, con cantidades iguales y almacenes diferentes. Se relacionan por movimiento y producto, sin un campo de enlace entre detalles. La entrada utiliza el costo real de la salida. Los ajustes registran la diferencia positiva y su signo; no se conserva el conteo físico en una columna separada.

## Flujo operativo

1. Configurar stock del producto terminado, almacén y receta. Los platos (tipos 3, 4 y 5) no tienen stock inicial ni admiten entradas manuales por compra o saldo inicial: solo ingresan por preparación de su receta.
2. Producción anticipada: registrar la cantidad realmente terminada. Se consumen ingredientes y se ingresan platos en la misma transacción.
3. Comandar: primero reserva los productos terminados disponibles. Para las unidades restantes con receta **aparta sus ingredientes** (`ven_pedido_reserva_insumo` por línea; el total en `alm_producto_stock.stock_reservado`), sin descontarlos. Si falta cualquier ingrediente, o un producto directo sin receta no tiene existencias, se rechaza toda la comanda (SQLSTATE `IN001`, faltantes en `DETAIL`) y el backend registra un aviso para cocina en `ven_aviso_cocina`. Reintentar la comanda actualiza el aviso pendiente del pedido.
4. Para lo que no estaba preparado, registrar producción vinculada al detalle del pedido (se puede en partes). Libera la parte proporcional de lo apartado y consume la receta en la misma transacción; las porciones quedan reservadas para esa línea. Si más tarde aparecen platos anticipados, la línea los toma y libera los ingredientes de esas unidades.
5. Entregar: descuenta el producto terminado y libera su reserva. No vuelve a consumir la receta.

Ejemplo, 21 platos con 5 preparados por adelantado: la comanda reserva los 5 y aparta los ingredientes de 16. Cocina ve «Listos: 5 · Por preparar: 16» y registra la preparación en partes (por ejemplo 10 y luego 6).

Los ingredientes apartados ya no figuran como disponibles para otros pedidos ni para la producción anticipada; `prod_disponibilidad` con `id_pedido_detalle` sí cuenta lo apartado por esa misma línea.

Una línea puede contener varias unidades. Una producción genera dos movimientos y cada entrega parcial genera su propia salida. Todos están vinculados al documento de producción o al detalle del pedido. La confirmación de inventario significa que se aplicó al stock, no que se entregó a mesa.

La producción se confirma cuando se declara terminada: este endpoint no modela ingredientes en proceso ni una fase de fabricación con consumo anticipado. Usa las cantidades vigentes de la receta al confirmar; el movimiento conserva los consumos efectivamente aplicados. No modificar recetas en uso para representar cambios retroactivos: crear una nueva versión.

Las recetas de producción anticipada no admiten grupos de sustitución: se preparan mediante un pedido con selección explícita. Los platos con insumos seleccionados o adicionales que consumen stock se preparan para ese pedido y no se abastecen con platos estándar. No pueden liberarse como platos estándar al cancelar; se registra merma. Los adicionales de precio sin consumo no impiden reservar un plato estándar. En productos directos sin receta, los adicionales con consumo se descuentan al entregar.

## Endpoints

| Método y ruta | Permiso | Uso |
|---|---|---|
| GET `/inventario/stock` | `inventario.ver` | Existencias; filtros `id_producto`, `id_almacen`, `limite` (máximo 200), `offset`. |
| GET `/inventario/kardex` | `inventario.ver` | Historial con los mismos filtros. |
| GET `/inventario/movimientos/:id` | `inventario.ver` | Cabecera y detalles. |
| POST `/inventario/movimientos` | `inventario.gestionar` | Crear movimiento; `confirmar` opcional. |
| POST `/inventario/movimientos/:id/confirmar` | `inventario.gestionar` | Aplicar borrador; repetir no duplica stock. |
| POST `/inventario/movimientos/:id/cancelar` | `inventario.gestionar` | Descartar borrador. |
| POST `/inventario/preparaciones` | `produccion.preparar` | Confirmar producción terminada. |
| POST `/pedidos/:id/items/:item_id/entregar` | `pedidos.entregar` | Entrega acumulada de una línea. |
| GET `/inventario/cocina/avisos` | `produccion.preparar` | Comandas rechazadas por falta de stock pendientes; filtros `id_sucursal` y `id_estacion`. |
| POST `/inventario/cocina/avisos/:id/atender` | `produccion.preparar` | Marcar el aviso como atendido. |

Los permisos se crean, pero no se conceden indiscriminadamente a roles; asignarlos mediante la administración de permisos existente.

Preparación anticipada:

```json
{
  "codigo": "PROD-20260930-001",
  "id_receta": 12,
  "id_almacen_destino": 2,
  "cantidad": 10
}
```

Para preparar lo pendiente de un pedido, añadir `id_pedido_detalle`. Se rechaza una cantidad superior a lo pendiente después de descontar reservas, entregas y cancelaciones. Un reintento con el mismo código, receta, cantidad, almacén y pedido devuelve la preparación existente.

Entrega de dos unidades acumuladas:

```json
{ "cantidad_entregada": 2 }
```

Si luego se entrega una unidad más, enviar `3`. Reenviar `2` no duplica la salida. Nunca enviar un incremento pensando que es el total acumulado.

Cancelación parcial mediante `DELETE /pedidos/:id/items/:item_id`:

```json
{
  "id_usuario_autoriza": 7,
  "motivo": "El cliente reduce la cantidad",
  "cantidad_cancelada": 1,
  "destino_preparado": "DISPONIBLE"
}
```

`cantidad_cancelada` también es acumulada. Omitirla cancela todas las unidades no entregadas. Primero se cancelan las unidades **sin plato preparado** y después las preparadas:

| Situación de las unidades canceladas | Resultado |
|---|---|
| Sin preparar, línea *Enviada* | Sus ingredientes apartados vuelven a estar disponibles. |
| Sin preparar, línea *En preparación* | `destino_insumos` obligatorio: `LIBERAR` (no se usaron) o `MERMA` (salida de merma de los ingredientes apartados). |
| Ya preparadas | `destino_preparado` obligatorio: `DISPONIBLE` las guarda en inventario para revender, `MERMA` las da de baja. Sus ingredientes no se devuelven. |

Toda cancelación exige autorización y motivo.

```json
{ "id_usuario_autoriza": 7, "motivo": "Mesa se retiró", "cantidad_cancelada": 3, "destino_insumos": "MERMA" }
```

Los ingredientes ya consumidos permanecen consumidos. La cancelación reduce el importe de las unidades pendientes. No se permite anular un pedido con productos entregados, pagos o comprobantes por este flujo: esos casos necesitan la devolución física y el reverso comercial correspondiente, que no se automatizan aquí.

## Integridad y pruebas

El inventario usa un bloqueo transaccional compartido entre movimientos, producción, reservas y entregas; los pedidos se bloquean antes. Esto prioriza consistencia y un orden predecible frente a máxima concurrencia entre almacenes. Salidas no pueden utilizar stock reservado a otros pedidos. Una falla revierte toda la operación, incluidos sus movimientos y reservas.

Los movimientos confirmados son inmutables. Los códigos de operación son únicos. La migración y el instalador son reejecutables.

```sh
npm run build
npm test -- --runInBand
npm run test:inventario:sql
```

La integración SQL utiliza exclusivamente PostgreSQL local en `127.0.0.1:55439`, usuario `pedidos_test`, crea una base temporal propia y la elimina al terminar. No lee `.env` ni utiliza la base de operación. Comprueba migración histórica, instalación repetida, reservas concurrentes, producción, costos de traslado, entrega/cancelación parcial, adicionales, reintentos, autorización, auditoría e inmutabilidad.
