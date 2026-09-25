# Listas compartidas

## Backend

`ListasModule` mantiene el patrón controller → logic → model → función PostgreSQL. Endpoints de lectura protegidos por el JWT global; disponibles para cualquier usuario autenticado porque son catálogos generales para formularios.

- `GET /general/listas`: listas activas con su ID real, código, nombre y descripción.
- `GET /general/listas/:id/opciones`: una lista activa y sus opciones activas.
- `GET /general/listas/codigo/:codigo/opciones`: misma respuesta, usando un código estable como `MESA_ESTADO`.

Las opciones se ordenan por `orden`, luego `id`. Una lista inactiva/inexistente devuelve 404; una lista activa sin opciones devuelve `opciones: []`. El interceptor existente mantiene el formato `{ success, message, data }`.

`data` incluye `id`, `codigo`, `nombre`, `descripcion` y `opciones`. Cada opción incluye `id`, `id_lista`, `codigo`, `nombre`, `descripcion`, `valor_entero` y `orden`.

## Instalación

Con el esquema y los catálogos existentes, ejecutar los archivos siguientes en el editor SQL:

1. `database_sql/funciones/general/listas/gen_listar_listas.sql`
2. `database_sql/funciones/general/listas/gen_obtener_lista_opciones.sql`

En psql se puede utilizar `database_sql/instalar_listas.sql`. Una función por archivo. No se reescriben seeds, IDs ni opciones existentes. Las funciones deben instalarse antes de utilizar los formularios que consumen este catálogo.

## Identificadores

El frontend centraliza los IDs numéricos reales de `gen_lista` en `src/modules/listas/constants/lista-ids.ts`, dentro de `LISTA_IDS`. El usuario administra esa correspondencia manualmente consultando `SELECT id, codigo FROM gen_lista ORDER BY id;`. Los 19 IDs actuales fueron configurados con los datos proporcionados por el usuario.

Los servicios del frontend consultan exclusivamente por ID: `GET /general/listas/:id/opciones`. Las opciones se filtran por `gen_lista_opcion.id_lista`. Para crear un nuevo catálogo, sembrarlo en la base y añadir su ID real a las constantes. El endpoint por código permanece disponible en el backend por compatibilidad, pero las vistas no lo utilizan.

`valor_entero` es el valor usado por columnas como `tipo_almacen`, `tipo_estacion` y `estado_mesa`; no equivale al ID de `gen_lista_opcion`.

## Pruebas

`npm test -- --runInBand listas`: validación de parámetros, normalización, consultas parametrizadas y respuesta 404 frente a lista vacía. Las pruebas se guardan en `test/listas/`, fuera de los módulos de producción.
