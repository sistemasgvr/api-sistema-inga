# Certificado QZ desde Estaciones

Antes de desplegar, ejecutar `database_sql/migraciones/20261014_qz_configuracion.sql` en la base de la API. También está incluido en `instalar_impresion.sql`.

La tabla es global para esta instalación, no por estación. El rol del backend debe ser propietario de la tabla (o contar con permisos y una política RLS específica); no conceder acceso a roles públicos, anon ni authenticated. La clave se almacena como texto en la base: restringir acceso y proteger los respaldos. No se devuelve por la API. Los archivos de fixtures son sólo de pruebas.

En Estaciones, un usuario con `estaciones.editar` carga el certificado y la clave PEM sin contraseña. Se validan RSA de al menos 2048 bits, correspondencia del par y vigencia. Ambos se reemplazan en una sentencia atómica. Un archivo inválido conserva la configuración anterior.

La base tiene prioridad sobre `QZ_CERTIFICATE_PATH` y `QZ_PRIVATE_KEY_PATH`; estas variables siguen disponibles como compatibilidad si no hay un par guardado. Una vez cargado no es necesario configurar rutas ni reiniciar la API. Recargar Inga en todas las PCs que imprimen tras cambiar el par. El guardado no instala QZ Tray ni configura la confianza del certificado en esas PCs.

GET `/impresion/qz/configuracion` devuelve sólo metadatos. POST en la misma ruta recibe `certificado` y `clavePrivada`; ambos endpoints requieren `estaciones.editar`. Usar HTTPS en producción.
