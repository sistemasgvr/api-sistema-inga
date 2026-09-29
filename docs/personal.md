# Personal: trabajadores y usuarios

`pla_trabajador` es la fuente de nombres, apellidos, teléfono, correo y sucursal.
`auth_usuario.id_trabajador` es obligatorio, único y una clave foránea. El usuario
guarda credenciales, estado y privilegios. Un trabajador puede existir sin cuenta;
una cuenta siempre pertenece a un trabajador. El vínculo no se reasigna al editar.

El correo es opcional para trabajadores sin cuenta y obligatorio para crear una
cuenta. Es único sin distinguir mayúsculas. Los datos personales se modifican
en **Personal → Trabajadores**; en **Personal → Usuarios** se selecciona un
trabajador activo con correo y sin cuenta y se configuran usuario, contraseña,
PIN y roles. Los pagos siguen en **Personal → Pagos de planilla**.

La vista interna `auth_usuario_datos` une ambas tablas sin duplicar los datos.
Mantiene los nombres de respuesta usados por los clientes, incluido
`id_sucursal_default`, que se obtiene de `pla_trabajador.id_sucursal`.
Login y validación de sesión exigen que el trabajador esté activo. Darlo de baja
cierra sus sesiones; reactivarlo requiere un nuevo inicio de sesión.
`cli_persona` conserva su función de clientes y proveedores.

## Instalación

Para una base nueva: ejecutar `database_sql/database.sql` y luego
`database_sql/instalar_personal.sql`, además de los instaladores habituales del proyecto.
El esquema reejecutable se regenera con `utilidades/generar_reejecutable.py`.

Para una base existente, desde la raíz de la API:

```powershell
node database_sql/utilidades/aplicar_personal.cjs
```

Sin opciones conserva operaciones y crea una ficha por usuario sin vínculo,
sin emparejar por nombre. Todo ocurre dentro de una transacción. Los correos
duplicados provocan reversión completa. El instalador se puede repetir.

## Reinicio de desarrollo autorizado

```powershell
node database_sql/utilidades/aplicar_personal.cjs --reset-desarrollo --dry-run
node database_sql/utilidades/aplicar_personal.cjs --reset-desarrollo
```

La simulación ejecuta exactamente las mismas acciones y termina con ROLLBACK.
El reinicio elimina usuarios, trabajadores, sesiones, asignaciones, pedidos,
turnos y pagos de planilla, junto con las filas que dependan de esas operaciones.
No vacía indiscriminadamente tablas de gastos o cuentas. Conserva catálogos,
limpia sus referencias de auditoría y recrea el único administrador activo con
sus credenciales y roles actuales. Luego genera su ficha de trabajador.
Se cierran las sesiones existentes y es necesario volver a iniciar sesión.

El reinicio exige exactamente un administrador activo, no se puede repetir tras
la migración y se rechaza con `NODE_ENV=production`. Si hay kardex de ventas,
se detiene antes de eliminar: el inventario debe revertirse previamente.

## Verificación

```powershell
npm run build
npm test -- --runInBand
node test/personal.integration.cjs
npm run test:pedidos:sql
```

Las pruebas SQL usan únicamente PostgreSQL temporal en 127.0.0.1:55439,
usuario `pedidos_test`, y crean/eliminan sus propias bases. No leen `.env`.
Verifican creación sin cuenta, vínculo único, correo único, actualización de
identidad, login, baja/reactivación, migración desde la estructura anterior,
reversión de la simulación y conservación del acceso administrativo.
