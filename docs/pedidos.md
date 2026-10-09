> Inventario actualizado: consultar [inventario.md](inventario.md) para instalación, producción, reservas y entregas.

# M05 — Pedidos, comandas e inventario

Se mantiene la arquitectura `controllers → logic → models → funciones SQL`.
Cada función está en su propio archivo de `database_sql/funciones/pedidos`.
Las pruebas están en `test/pedidos`, fuera de `src/modules`.

## Instalación

Con el esquema del proyecto ya creado, ejecutar **una sola vez el instalador** (también admite reejecución):

```sh
psql "<conexion_de_la_base>" -v ON_ERROR_STOP=1 -f database_sql/instalar_pedidos.sql
```

Los comandos `\ir` son de **psql**. Para otro cliente SQL, ejecutar los archivos incluidos en ese mismo orden dentro de una transacción.
El instalador aplica la migración `02_ven_pedidos.sql`, las funciones y los permisos.
No ejecuta `database.sql` ni elimina datos. Si hay más de un pedido en curso en una mesa, el índice único detendrá la instalación: primero resolver esos pedidos.
La migración agrega tasa de IGV por pedido, la condición de precio del producto por ítem, selección de insumos opcionales y auditoría de anulación.

Asignar los permisos `pedidos.ver`, `pedidos.abrir`, `pedidos.editar`, `pedidos.comandar`, `pedidos.estado` y `pedidos.anular` mediante el módulo de roles existente. El seed no concede permisos automáticamente.

Variable opcional del backend: `PEDIDOS_TASA_IGV=18` (porcentaje, predeterminado 18). La tasa se copia al abrir cada pedido; cambiar la configuración no cambia pedidos anteriores.

## Endpoints

Todos requieren el JWT del sistema. Devuelven el pedido completo con `items`, sus `adicionales` y `comandas`, dentro del formato de respuesta global de la API.
Los IDs de los ejemplos deben reemplazarse por registros de la base.

| Método | Ruta | Permiso |
|---|---|---|
| GET | `/pedidos/:id` | `pedidos.ver` |
| POST | `/pedidos` | `pedidos.abrir` |
| POST | `/pedidos/:id/items` | `pedidos.editar` |
| PUT | `/pedidos/:id/items/:item_id` | `pedidos.editar` |
| DELETE | `/pedidos/:id/items/:item_id` | `pedidos.anular` |
| POST | `/pedidos/:id/comandar` | `pedidos.comandar` |
| PUT | `/pedidos/:id/estado` | `pedidos.estado` y, para destinos 2/5, `pedidos.comandar` / `pedidos.anular` |
| POST | `/pedidos/:id/anular` | `pedidos.anular` |

### Abrir un pedido

```json
{
  "tipo_pedido": 1,
  "id_mesa": 12,
  "id_mozo": 7,
  "id_turno": 5,
  "num_comensales": 2,
  "observacion": "Atención en terraza"
}
```

Tipos: 1 MESA, 2 LLEVAR, 3 DELIVERY. MESA requiere una mesa activa y LIBRE y obtiene la sucursal de su salón. Para LLEVAR/DELIVERY enviar `id_sucursal` y omitir `id_mesa`.
El mozo debe ser un usuario activo. El turno es obligatorio, debe estar abierto y pertenecer a una caja activa de esa sucursal. El código del pedido se genera en el servidor.

### Agregar un ítem

```json
{
  "id_producto": 20,
  "id_receta": 4,
  "cantidad": 2,
  "precio_unitario": 23.60,
  "observacion": "Sin ají",
  "adicionales": [{ "id_adicional": 3 }],
  "insumos_seleccionados": [15]
}
```

- `cantidad`: positiva, máximo 4 decimales; `precio_unitario`: no negativo, máximo 2 decimales. Si se omite el precio, se toma el catálogo.
- `id_receta`: opcional; se elige la receta vigente del producto cuando corresponde. Los platos y tragos requieren receta activa. Un producto con stock directo no descuenta también una receta.
- `adicionales`: opcional, sin duplicados, deben pertenecer al producto. El precio se obtiene del catálogo; cada adicional se multiplica por la cantidad del ítem.
- `insumos_seleccionados`: opcional, IDs de **pro_receta_insumo**. Los insumos obligatorios sin grupo se incluyen automáticamente. En cada grupo obligatorio de sustitución se debe elegir exactamente uno; en grupos opcionales, como máximo uno. Los insumos opcionales sin grupo solo se consumen si se seleccionan.
- Producto y estación deben estar activos, disponibles y corresponder a la sucursal. Los insumos deben tener almacén de stock activo de esa sucursal y conversión de unidad cuando corresponda.

Se pueden agregar nuevas rondas en ABIERTO o COMANDADO. Cada envío procesa solo los ítems pendientes.

### Editar un ítem pendiente

```json
{ "cantidad": 3, "observacion": "Sin sal" }
```

Se admite uno o ambos campos. No cambia producto, receta, precio ni adicionales. Un ítem comandado o anulado no se edita.

### Comandar

`POST /pedidos/:id/comandar`, sin cuerpo.

Genera una comanda por estación con numeración por pedido/estación. Con la migración de impresión instalada, encola el ticket y notifica al receptor QZ Tray por WebSocket; ver [impresión](impresion.md). No envía al KDS.
Reserva productos terminados disponibles y aparta los ingredientes del resto, sin descontar existencias. Si falta stock se rechaza toda la comanda (HTTP 409) y se avisa a cocina. La preparación confirmada consume receta e ingresa el terminado. La entrega del detalle descuenta el producto terminado. Los reintentos sin nuevos ítems no duplican comandas ni reservas.

La entrega se registra con POST /pedidos/:id/items/:item_id/entregar y un total acumulado cantidad_entregada. Ver los ejemplos y reglas de cancelación parcial en inventario.md.

### Cambiar estado

```json
{ "estado_pedido": 3 }
```

Estados: 1 ABIERTO → 2 COMANDADO → 3 POR_COBRAR → 4 PAGADO. Desde 1, 2 o 3 puede pasar a 5 ANULADO con autorización y motivo.
Enviar estado 2 ejecuta la misma operación de comandar; enviar 5 ejecuta la anulación completa. No son atajos para omitir inventario.
POR_COBRAR exige que todas las unidades no canceladas estén entregadas y pone la mesa en estado 3.
PAGADO exige que la suma de `ven_pago` activos cubra el total; actualiza `monto_pagado`, fecha de cierre y libera la mesa. El registro de pagos corresponde al módulo de cobro y no se crea desde este endpoint.

### Anular ítem o pedido

El DELETE de un ítem y el POST de anulación requieren este cuerpo:

```json
{ "id_usuario_autoriza": 7, "motivo": "Solicitud del cliente" }
```

El autorizador debe ser **el usuario autenticado**, activo y con el permiso `pedidos.anular`, obtenido mediante asignaciones y roles activos, o ser superadministrador. El nombre o código del rol no concede autorización por sí solo. No basta enviar el ID de otra persona; debe usarse la sesión del autorizador. La base de datos vuelve a validar el permiso y exige motivo incluso al superadministrador.
Se pueden cancelar unidades no entregadas, antes o después de comandar. cantidad_cancelada indica el total acumulado de la línea. Si se cancelan platos preparados, destino_preparado debe indicar DISPONIBLE o MERMA; si se cancelan unidades sin preparar de una línea en preparación, destino_insumos debe indicar LIBERAR o MERMA (ver inventario.md). Los ingredientes utilizados no se devuelven. La anulación total requiere que no haya productos entregados, pagos ni comprobantes. Se conservan cantidades, autores y movimientos para auditoría.

## Regla de IGV acordada

En este módulo, `pro_producto.afecto_igv` se interpreta según la regla solicitada:

| Valor al agregar el ítem | Precio de catálogo | Base | IGV (18%) | Total |
|---|---:|---:|---:|---:|
| true: incluye IGV | 11.80 | 10.00 | 1.80 | 11.80 |
| false: agregar IGV | 10.00 | 10.00 | 1.80 | 11.80 |

Se copia ese valor al detalle y se conserva el precio de cada adicional. Los adicionales usan la misma condición del ítem principal. `ven_pedido_detalle.monto_subtotal` guarda el importe de línea (cantidad × precio con adicionales, antes de agregar/desglosar IGV); `ven_pedido.monto_subtotal` guarda la base sin impuesto. El impuesto se redondea por línea a dos decimales.

## Transacciones y pruebas

Cada mutación es una única llamada SQL atómica. Los errores revierten también inventario, kardex, comandas y mesa. Los pedidos de una mesa se serializan con el mismo bloqueo usado en Ambientes; el inventario se bloquea por almacén/producto en orden estable.
Los futuros flujos de cobro/devolución deben bloquear primero el pedido antes de registrar o anular pagos, para mantener la misma garantía frente a transiciones concurrentes.

```sh
npm run build
npm test -- --runInBand
npm run test:pedidos:sql
```

La última prueba requiere una instancia PostgreSQL **temporal**, usuario `pedidos_test`, host `127.0.0.1`, puerto `55439`. No lee `.env`; crea su propia base `inga_pedidos_test_<timestamp>` y la elimina al terminar. Carga el esquema real del proyecto y reejecuta el instalador para comprobarlo.

Ejemplo PowerShell usando PostgreSQL ya instalado (ajustar únicamente la ruta de binarios):

```powershell
& 'C:/Program Files/PostgreSQL/18/bin/initdb.exe' -D '.tmp/pedidos-pg' -U pedidos_test -A trust --encoding=UTF8 --locale=C
& 'C:/Program Files/PostgreSQL/18/bin/pg_ctl.exe' -D '.tmp/pedidos-pg' -l '.tmp/pedidos-pg.log' -o '-h 127.0.0.1 -p 55439' -w start
npm run test:pedidos:sql
& 'C:/Program Files/PostgreSQL/18/bin/pg_ctl.exe' -D '.tmp/pedidos-pg' -m fast -w stop
```

La prueba compartida verifica producción, conversión de unidades, adicionales, reservas concurrentes, autorización, pertenencia de ítems, entrega y cancelación parciales, reintentos, costos de traslado y atomicidad tras fallos.
