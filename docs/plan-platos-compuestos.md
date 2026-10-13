# Plan: platos hechos de otros platos (caso "Barco")

> Estado: **pendiente de revisión**. No se ha implementado nada.

## Problema

`ven_consumos_item.sql` trata cada línea de `pro_receta_insumo` como un insumo de un solo nivel. Cuando el Barco lleva "Ceviche" y "Chicharrón", el sistema intenta apartar *el plato Ceviche* de `alm_producto_stock`. Ese stock casi siempre es 0, porque se produce bajo pedido. Entonces `ven_reservar_insumos_pedido` lanza `IN001 "No hay stock suficiente… Ceviche (falta 1 und)"` y la comanda se rechaza, sin revisar si hay ingredientes para preparar el Ceviche.

## Lo que ya existe

| Flujo | Dónde está | Estado |
|---|---|---|
| Cancelar un plato preparado, eligiendo entre desecharlo o guardarlo en stock | `ven_cancelar_stock_item.sql` (`destino_preparado`: `DISPONIBLE` / `MERMA`). En el front: `accion-cocina-modal.tsx` y `pedido-panel.tsx` | ✅ Funciona |
| Cancelar con ingredientes apartados (devolverlos al almacén o mermarlos) | `destino_insumos`: `LIBERAR` / `MERMA` | ✅ Funciona |
| Un plato personalizado no puede volver al stock | El backend obliga a registrarlo como `MERMA` | ✅ Funciona |
| Preparar platos sin pedido | Botón "Preparación anticipada" en `cocina-view.tsx` → `prod_preparar` sin `id_pedido_detalle` | ✅ Funciona para platos simples; ❌ falla con platos hechos de otros platos |
| Stock libre = `stock_actual - stock_reservado` | Todas las reservas | ✅ Un plato asignado a un pedido nunca se toma |
| El Barco usa sub-platos libres o sus ingredientes | — | ❌ Falta |

## Regla central

**El stock libre de un plato** es lo que queda de la preparación anticipada más lo que volvió de pedidos cancelados con "guardar en stock". No incluye nada asignado a un pedido.

Cualquier pedido puede tomar ese stock libre: un pedido de Ceviche o un Barco que necesita Ceviche. El primero que comanda se lo lleva, y queda reservado a su nombre.

Para cada sub-plato (componente con receta vigente):

1. Primero se usa el plato preparado **libre**.
2. Lo que falte se reemplaza por sus ingredientes, de forma recursiva y con un límite de profundidad. El guard anti-ciclos de `pro_guardar_receta_insumo` ya evita los ciclos.
3. Se mantiene el "todo o nada": si falta cualquier ingrediente final, se rechaza la comanda y el aviso indica la ruta, por ejemplo `Barco › Ceviche: Limón (falta 0.2 kg)`.

## Flujos

### Flujo 1: cancelar un plato ya preparado

1. El mozo o el chef cancela una línea con unidades preparadas.
2. El sistema pregunta qué hacer con el plato:
   - **Guardar en stock** → se quita la reserva y el plato queda libre para otro pedido o para un Barco.
   - **Desechar** → se quita la reserva y se registra una salida `MERMA` en el Kardex.
3. Si el plato era personalizado, solo se permite desechar.
4. **Nuevo:** si la línea cancelada es un Barco y tenía apartado un Ceviche preparado (no ingredientes), ese Ceviche vuelve a la misma pregunta: guardar en stock o desechar. Si la preparación no había empezado, vuelve al stock solo.

### Flujo 2: preparación anticipada (sin pedido)

1. En cocina → "Preparación anticipada" → se elige el plato (Ceviche, o también el Barco) y la cantidad.
2. El modal muestra los ingredientes necesarios, agrupados por sub-plato si es un Barco, y cuántos se pueden preparar.
3. Al confirmar: salen los ingredientes (`PRODUCCION_CONSUMO`), entra el plato terminado (`PRODUCCION_ENTRADA`) **sin reservar**, y queda libre.
4. **Nuevo:** si el plato tiene sub-platos, se usan primero los sub-platos libres y el resto se cubre con ingredientes.
5. Se mantiene: no se puede anticipar una receta con grupos de sustitución, porque esa elección depende del cliente.

### Flujo 3: comandar un Barco

Por cada Barco pedido:

1. ¿Hay Barcos libres? → se reservan (ya existe en `ven_reservar_item`).
2. Para los Barcos que falten, se recorren sus componentes:
   - Sub-plato (Ceviche) → se reserva primero del Ceviche **libre**; lo que falte se convierte en sus ingredientes.
   - Insumo directo (canchita) → se reserva.
3. Si falta cualquier cosa → se rechaza la comanda y se crea un aviso a cocina con la ruta (`Barco › Ceviche › Limón`).
4. Todo se guarda en `ven_pedido_reserva_insumo` con `id_producto_origen`.
5. Si se tomó un sub-plato preparado, se suma a su `stock_reservado`, para que ningún otro pedido lo tome.

### Flujo 4: preparar el Barco del pedido (vista del chef)

1. El chef presiona "Preparar" y ve lo que se apartó, agrupado:
   - **Ceviche:** 1 und *(preparado, del stock)*
   - **Chicharrón:** cerdo 0.3 kg, papa 0.2 kg… *(con ingredientes)*
   - **Directo del Barco:** canchita 50 g
2. Al confirmar, se consume **exactamente lo reservado**, platos y/o ingredientes, y entra el Barco ya reservado para el pedido.
3. No se vuelve a calcular con el stock del momento, así que nada cambia entre comandar y preparar.
4. Los sub-platos preparados **para** el Barco no entran como stock propio: sus ingredientes se descuentan directo al producir el Barco.

### Flujo 5: entregar

Sin cambios: sale el Barco reservado (`VENTA`).

## Casos y resultado esperado

| # | Situación | Resultado |
|---|---|---|
| 1 | Ceviche preparado para la mesa 3; llega un Barco | El Barco **no** lo toma (está reservado); usa ingredientes |
| 2 | La mesa 3 cancela el Ceviche → "Guardar en stock" | Queda 1 Ceviche libre |
| 3 | Después llega un Barco | Toma ese Ceviche libre y prepara con ingredientes solo el Chicharrón |
| 4 | La mesa 3 cancela el Ceviche → "Desechar" | Merma; el Barco usa ingredientes |
| 5 | Ceviche personalizado cancelado | Solo se puede desechar; nunca llega a un Barco |
| 6 | 2 Ceviches anticipados libres; llegan 2 Barcos y 1 Ceviche, en ese orden | Cada Barco toma 1 Ceviche libre; el pedido de Ceviche usa ingredientes |
| 7 | Dos comandas al mismo tiempo compiten por 1 Ceviche libre | `alm_bloquear()` las procesa una por una: solo una lo toma y la otra usa ingredientes |
| 8 | 1 Ceviche libre, el Barco necesita 2 | 1 del stock + 1 con ingredientes |
| 9 | No hay Ceviche libre ni limón | Se rechaza la comanda y el aviso dice `Barco › Ceviche: Limón falta X` |
| 10 | Se cancela un Barco sin preparar que había tomado un Ceviche del stock | El Ceviche vuelve al stock libre y los ingredientes se devuelven |
| 11 | Se cancela un Barco ya en preparación | Se pregunta: Ceviche guardar/desechar; ingredientes devolver/merma |
| 12 | Se cancela un Barco ya preparado → "Guardar en stock" | Queda 1 Barco libre; el próximo pedido de Barco lo toma completo |
| 13 | Barco anticipado sin pedido | Usa Ceviches libres y luego ingredientes; el Barco queda libre |
| 14 | El sub-plato tiene grupos de sustitución | Se rechaza con un mensaje claro (comandar o anticipar) |
| 15 | Líneas comandadas antes de la migración | Funcionan con el cálculo actual (respaldo) |

## Cambios técnicos

### Base de datos

1. **Migración `database_sql/migraciones/09_reserva_insumo_origen.sql`**
   - Agregar `id_producto_origen BIGINT NULL` en `ven_pedido_reserva_insumo` (NULL = componente directo del plato; si no, el sub-plato del que sale).
   - Cambiar el UNIQUE a `(id_pedido_detalle, id_producto, id_almacen, COALESCE(id_producto_origen, 0))`.
2. **Nueva función `pro_explotar_receta(p_receta, p_cantidad, p_seleccionados)`** en `productos-recetas-insumos/`
   - Devuelve: producto, almacén, unidad, cantidad, `id_producto_origen`, `ruta` y `es_subplato`.
   - Por cada unidad del sub-plato: `ri.cantidad × (1 + merma) × ven_factor_unidad(ri.unidad, sub.unidad) / sub.rendimiento_porciones`.
   - Usa la receta vigente (`estado = 1 AND vigente`, última versión). Excluye opcionales del sub-plato. Rechaza sub-platos con grupos de sustitución.
   - Reemplaza los tres cálculos repetidos de hoy (`ven_consumos_item`, `prod_disponibilidad`, `prod_preparar` anticipada).
3. **`ven_consumos_item`**: sigue validando el primer nivel (sustituciones e `insumos_seleccionados`). Para los sub-platos devuelve el sub-plato marcado `es_subplato`, sin explotarlo; la decisión entre plato preparado e ingredientes se toma al reservar.
4. **`ven_reservar_insumos_pedido`**:
   - Por cada sub-plato toma `LEAST(necesario, libre)` del plato preparado y explota solo el resto.
   - Lleva en memoria cuánto queda libre para que dos líneas de la misma comanda no tomen dos veces el mismo stock.
   - Guarda las reservas con `id_producto_origen` y agrega `ruta` a los faltantes de `IN001`.
5. **`prod_preparar`**:
   - Por pedido: consumir exactamente lo que se reservó (el JSON que devuelve `ven_liberar_insumos` ya viene en formato `alm_aplicar`). El recálculo con `ven_consumos_item` queda solo como respaldo para líneas sin reserva por origen.
   - Anticipada: usar sub-platos libres y luego ingredientes con el stock del momento.
6. **`prod_disponibilidad`**:
   - Agregar `id_producto_origen`, `origen`, `ruta` y si sale del stock o de ingredientes a cada componente.
   - Con `p_item`, se arma desde la reserva de esa línea.
   - `posibles_preparar` deja de ser lineal con sub-platos: calcularlo con búsqueda binaria sobre la explosión, o mostrar solo si alcanza para la cantidad pedida.
7. **`ven_cancelar_stock_item`**: las reservas de sub-platos preparados siguen la decisión guardar/desechar (caso 11). Hoy, para unidades sin preparar, solo se pide `destino_insumos`.

### Backend NestJS

- Casi no cambia porque la lógica está en SQL.
- Si se tipa la respuesta de disponibilidad en `inventario`, actualizar respetando la arquitectura (`models/` → `logic/` → `controllers/`, DTO en `dto/`).
- Si cambia la cancelación (caso 11), ajustar `dto/pedido.dto.ts`.

### Frontend

- `cocina.types.ts`: agregar `origen`, `id_producto_origen` y `ruta` a `Disponibilidad.ingredientes` y a `FaltanteCocina`.
- `preparacion-modal.tsx`: agrupar la tabla por sub-plato y marcar lo que sale del stock preparado.
- Cancelación (`accion-cocina-modal.tsx`, `pedido-panel.tsx`): pregunta extra cuando el Barco tiene sub-platos preparados apartados.
- Aviso de faltantes: mostrar la `ruta`.
- Cocina: mostrar el **stock libre** de cada plato preparable (`prod_listar_productos` ya tiene los datos).

## Verificación

- Agregar los 15 casos a `npm run test:inventario:sql`.
- Backend: `npm run build` y los tests del módulo.
- Frontend: `npx tsc --noEmit`.
- Antes de empezar: revisar en la base la receta real del Barco (unidades y rendimientos de sus sub-platos) para usarla como caso de prueba.

## Orden de implementación sugerido

1. Migración 09 y `pro_explotar_receta`, con tests de los casos 1 a 9.
2. `ven_consumos_item`, `ven_reservar_insumos_pedido` y `prod_preparar` (por pedido y anticipada).
3. `prod_disponibilidad` y `ven_cancelar_stock_item` (casos 10 a 15).
4. Frontend: modal agrupado, cancelación, avisos y stock libre.

## Pendiente de decidir

- **Platos preparados libres que se quedan días en stock:** agregar al cierre de turno un paso que liste los platos preparados libres para elegir entre mantenerlos o desecharlos (merma). ¿Se incluye ahora o después?
- **Sub-platos con grupos de sustitución:** la propuesta es rechazarlos. La alternativa es tomar automáticamente la primera opción de cada grupo.
