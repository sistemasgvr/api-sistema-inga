# M05 · Ambientes (primera etapa)

## Arquitectura

- Backend: `SalonModule` registrado en `AppModule`; controladores → `SalonLogic` → `SalonModel` → `DatabaseService.callFunctionJson` → funciones PostgreSQL. DTO con validación global, JWT, permisos, Swagger y formato de respuesta compartidos.
- Frontend: `/ambientes`, módulo con tipos, servicios HTTP, hook de estado y componentes. Reutiliza cliente Axios, `RoleGuard`, menú, botones, alertas, formularios modales, confirmaciones, selectores, tabla e iconos existentes. Conserva tokens de marca y modo oscuro.
- `react-rnd` controla la geometría de **salones** usando `ven_salon.posicion_x`, `posicion_y`, `ancho` y `alto`. Guarda mediante PATCH al soltar; si falla, restaura la geometría previa. También se pueden editar los valores desde el formulario, sin arrastrar.
- Las mesas se distribuyen dentro del salón en una cuadrícula. `ven_mesa` no tiene coordenadas: no se añaden campos ni se simula persistencia de una posición individual.

## Instalación en PostgreSQL

Los archivos del esquema existentes, incluidos los cambios previos en `database.sql`, se conservan. Sobre una base con el esquema del proyecto, ejecutar **en este orden**:

1. `database_sql/migraciones/01_ven_salon_geometria.sql`
2. Los archivos individuales de `database_sql/funciones/salon/`, en el orden indicado por `database_sql/instalar_ambientes.sql` (funciones de consulta antes de las que las invocan).
3. `database_sql/seeds/permisos/09_ambientes.sql`

En psql se instala el módulo con `database_sql/instalar_ambientes.sql`, que incluye los archivos dentro de una transacción. En pgAdmin u otro editor, ejecutar los archivos anteriores por separado y en ese mismo orden. La migración incorpora los campos de geometría si una instalación antigua no los tiene; cada archivo de funciones crea/reemplaza únicamente la función de su mismo nombre. No elimina datos.

Convención para futuras implementaciones: **una función PostgreSQL por archivo**, nombrado exactamente `<nombre_funcion>.sql`, dentro de la carpeta del módulo. Mantener las migraciones de tablas, los seeds y los instaladores separados de las definiciones de funciones. Esta regla también está registrada en `AGENTS.md`.

Asignar `ambientes.listar` y, para administradores de espacios, `ambientes.gestionar` mediante la gestión existente de roles. Los superadministradores conservan el acceso global. Renovar la sesión si se modifican los permisos del usuario.

## Endpoints

| Método | Ruta | Permiso |
| --- | --- | --- |
| GET | `/salon/salones/sucursales` | `ambientes.listar` |
| GET / POST | `/salon/salones` | listar / gestionar |
| GET / PATCH / DELETE | `/salon/salones/:id` | listar / gestionar / gestionar |
| PATCH | `/salon/salones/:id/activar` | gestionar |
| GET / POST | `/salon/mesas` | listar / gestionar |
| GET / PATCH / DELETE | `/salon/mesas/:id` | listar / gestionar / gestionar |
| PATCH | `/salon/mesas/:id/activar` | gestionar |

Listados: `id_sucursal`, `estado=activos|inactivos|todos`, `buscar`, `pagina`, `limite`; las mesas también admiten `id_salon`. El frontend recorre todas las páginas para completar el plano.

Crear salón:

```json
{"id_sucursal":1,"codigo":"SAL-01","nombre":"Principal","posicion_x":20,"posicion_y":20,"ancho":360,"alto":260}
```

Crear mesa:

```json
{"id_salon":1,"codigo":"M-01","capacidad_personas":4,"estado_mesa":1}
```

Las actualizaciones son parciales. La auditoría se toma de `request.user.id`, nunca del cuerpo del cliente. DELETE es baja lógica; activar no borra historial.

## Reglas

- Código único por sucursal/salón, incluyendo registros inactivos; textos obligatorios sin espacios vacíos.
- X/Y entre 0 y 10000; ancho entre 200 y 5000; alto entre 150 y 5000. Unidad: píxeles del plano. Capacidad entera entre 1 y 100.
- Salón y sucursal de destino activos. No se cambia la sucursal de un salón con mesas registradas.
- Un salón con mesas activas no se puede desactivar. Una mesa con estado ocupado/por cobrar o pedidos activos abiertos/comandados/por cobrar no se puede editar ni desactivar.
- El mantenimiento solo asigna LIBRE (1) e INHABILITADA (4). OCUPADA (2) y POR_COBRAR (3) se muestran, pero su asignación corresponde al flujo de pedidos de la siguiente etapa.
- Las funciones bloquean filas durante las escrituras. El mantenimiento de una mesa se serializa antes de resolver sus salones para proteger cambios concurrentes de ubicación y baja.

## Verificación

Las pruebas automatizadas `.spec.ts` se ubican en `test/salon/`, fuera de las carpetas de producción del módulo. Comprueban validaciones y respuestas de error al ejecutar Jest; no forman parte del flujo de los endpoints. Para futuras implementaciones, mantener la estructura de los módulos existentes (`controllers`, `dto`, `logic`, `models` y archivo del módulo) y ubicar las pruebas que se necesiten en `test/<modulo>/`.

Backend: `npm run build`, `npm test -- --runInBand salon` y `npx eslint src/modules/salon`.

Prueba PostgreSQL: `node --env-file=.env test/ambientes-db.cjs`. Requiere conectividad y permisos para tablas temporales y funciones en `pg_temp`. Usa tablas temporales y ROLLBACK; no modifica datos ni funciones del esquema público. Verifica persistencia, unicidad, estados, bajas, reactivación, filtros y bloqueo de mesas con pedidos.

Frontend: `npx tsc --noEmit` y `npx eslint src/modules/ambientes "src/app/(dashboard)/ambientes/page.tsx"`.

Prueba manual tras instalar SQL: crear salón y mesas, mover/redimensionar y recargar; editar capacidad; inhabilitar; desactivar/reactivar; cambiar sucursal; comprobar acceso de solo lectura. Los endpoints de pedidos, comandas, stock y cobros quedan para las siguientes etapas.
