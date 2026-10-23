# Notificaciones

Módulo `src/modules/notificaciones`. Envía avisos en tiempo real por Socket.IO
(namespace `/notificaciones`) y guarda el historial con su estado de lectura por usuario.

## Instalación en base de datos

Después de `migraciones/15_notificaciones.sql`, ejecutar:

```
psql ... -f database_sql/instalar_notificaciones.sql
```

Agrega destinatarios, outbox, recordatorios, el trigger de stock mínimo y las funciones nuevas.

## Canales y permisos

`constants/canales.ts` define qué permiso hace falta para recibir cada canal:

| Canal | Permiso | Eventos |
|---|---|---|
| `pedidos` | `pedidos.ver` | precuenta, pedido anulado, producto anulado |
| `cocina` | `produccion.preparar` | nueva comanda, stock insuficiente para comandar |
| `caja` | `turnos.listar` | turno cerrado, faltante/sobrante, caja abierta desde un día anterior |
| `inventario` | `inventario.ver` | stock bajo, producto agotado |
| `ventas` | `ventas.listar` | pedido cobrado o a crédito |
| `planilla` | `planilla.pagos.listar` | pago registrado/anulado, pagos pendientes de la quincena |
| `cuentas-por-pagar` | `cxp.listar` | cargo, abono |
| `cuentas-por-cobrar` | `cxc.listar` | consumo, abono |
| `gastos` | `gastos.listar` | gasto administrativo |
| `gastos-diarios` | `gdo.listar` | compra del día |
| `sistema` | — | avisos generales |

Al conectar, el socket recibe todos los canales permitidos. Una notificación con
`idsUsuario` llega solo a esos usuarios. Las rutas del front se arman con
`constants/rutas-notificacion.ts`.

## Avisos generados en SQL (outbox)

La base usa el pooler de Supabase en modo transacción, donde `LISTEN/NOTIFY` no es
fiable. Los avisos que nacen en SQL se insertan con `emitida_en = NULL` y
`NotificacionesLogic.despachar()` los envía por socket:

- cada 10 s;
- al instante tras entregar platos, operaciones de inventario y compras del día.

`not_pendientes_emitir` usa `FOR UPDATE SKIP LOCKED`, así que varias instancias no
duplican envíos. Con `NOTIFICACIONES_DESPACHADOR=false` se desactiva el despachador
y las tareas periódicas en esa instancia.

### Stock mínimo

Trigger `alm_trg_alerta_stock` sobre `alm_producto_stock`. Suma el stock de todos
los almacenes del producto y compara con la suma de sus mínimos (solo productos
con mínimo mayor que 0). `alm_alerta_stock_estado` guarda el último nivel avisado
(0 normal, 1 bajo, 2 agotado): se avisa solo cuando el nivel empeora, y al reponer
vuelve a 0 para avisar de nuevo en la próxima caída.

### Recordatorios y depuración

Cada hora (y 15 s después de arrancar) se llama `not_generar_recordatorios()`:

- **Quincena**: trabajadores activos sin pago de la quincena que acaba de cerrar
  (1ra desde el día 15; 2da el último día del mes y hasta el 14 del siguiente).
- **Caja**: turnos abiertos desde un día anterior.

Cada recordatorio lleva una `clave_unica` con la fecha, así sale una vez al día
a cualquier hora. Luego `not_depurar(60)` borra el historial de más de 60 días.

## API REST

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/notificaciones?soloNoLeidas&canal&limite&offset` | `{ registros, total }` |
| GET | `/notificaciones/no-leidas/count` | `{ total }` |
| PATCH | `/notificaciones/:id/leer` | marca una como leída |
| PATCH | `/notificaciones/leer-todas` | marca todas (opcional `{ canal }`) |
| POST | `/notificaciones` | alta manual, solo super administrador |

Eventos de socket: `notificacion:nueva`, `notificacion:leidas` (sincroniza pestañas
del mismo usuario), `notificacion:conectado`, `notificacion:error`.
