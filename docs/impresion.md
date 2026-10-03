# Comandas con QZ Tray y WebSocket

## Instalación

1. Instalar las dependencias con `npm ci` en ambos proyectos.
2. Después de instalar el módulo de pedidos, ejecutar en PostgreSQL:
   `psql "$DATABASE_URL" -f database_sql/instalar_impresion.sql`.
   La migración se puede repetir. No incorpora comandas históricas a la cola.
3. Configurar en el backend `QZ_CERTIFICATE_PATH` y `QZ_PRIVATE_KEY_PATH` con rutas
   a `digital-certificate.txt` y la clave RSA PEM proporcionados/configurados para QZ.
   La clave debe quedar sólo en el servidor, fuera del repositorio y del frontend.
   La impresión silenciosa requiere un certificado confiable para QZ Tray y autorizar
   el sitio en el equipo. Consultar https://qz.io/docs/signing.
   Para pruebas con diálogos se permite `QZ_ALLOW_UNSIGNED=true` únicamente fuera de
   `NODE_ENV=production`. No es la configuración de operación desatendida.
4. Publicar backend y frontend. El proxy del VPS debe reenviar WebSocket en
   `/socket.io/` al mismo backend NestJS. El namespace es `/impresion`.
   `NEXT_PUBLIC_API_URL` apunta a la base pública del API. Si el proxy monta Socket.IO
   bajo otro prefijo, configurar `NEXT_PUBLIC_SOCKET_PATH` en el frontend antes de compilar.
5. Instalar QZ Tray 2.2 o superior desde https://qz.io/download/ en la PC de caja y
   habilitar su inicio con Windows. La PC debe alcanzar las IP de las impresoras.
6. Iniciar sesión con `estaciones.listar` y `pedidos.comandar` (o superadministrador).
   En **Estaciones**, configurar una IP por impresora, verificarla con **Probar conexión** o
   **Imprimir hoja de prueba** y marcar **Imprimir comandas en esta PC**: la recepción empieza
   al marcar la primera estación y se detiene al desmarcar todas (o con **Dejar de imprimir aquí**).
   Un indicador en la cabecera muestra el estado en cualquier pantalla. Las estaciones elegidas se guardan por usuario y navegador. Configurar sólo las que
   esta PC debe atender; los permisos del sistema actual son globales, no por sucursal.

## Operación y recuperación

- El receptor permanece montado en el layout autenticado al cambiar de pantalla.
  Mantener navegador abierto, sesión vigente, QZ Tray activo y PC sin suspensión.
- La transacción que crea `ven_comanda` inserta, al confirmar, un trabajo y una copia
  del ticket con sus ítems/adicionales/observaciones. Si la transacción falla, no hay trabajo.
- NestJS notifica inmediatamente después de comandar. El cliente también solicita
  pendientes al reconectar y cada 15 segundos, para recuperar señales perdidas o de otra
  instancia del backend. WebSocket lleva JWT; se revalidan sesión y permisos en cada solicitud.
- PostgreSQL asigna cada trabajo con `FOR UPDATE SKIP LOCKED`. El propietario es un UUID
  generado por el servidor. Varias pestañas/PC no pueden reclamar el mismo pendiente.
- Confirmar QZ significa **enviado**, no confirmación física del papel. `fecha_impresion`
  conserva ese significado de envío aceptado. Falta de papel/atascos dependen del hardware.
- Los ACK se guardan localmente y se reintentan sin imprimir otra vez si falla Internet.
- Ante un fallo de QZ se pausa el receptor y el trabajo pasa a **revision**. Revisar **Ver cola**,
  elegir **Reintentar envío** o **Ya salió en papel**, y pulsar **Reanudar**.
- Si se cierra el navegador después de reclamar un trabajo, queda **procesando**. Después
  de dos minutos puede resolverse manualmente. Comprobar físicamente la impresora y detener
  cualquier receptor anterior antes de reintentar: la impresión RAW no ofrece exactamente
  una vez frente a una caída entre el envío físico y la confirmación.
- Las comandas anuladas o de pedidos anulados no se entregan como pendientes. Un trabajo
  ya enviado al equipo no se puede retirar. Esta integración no imprime avisos de anulación.

## Compatibilidad

Se implementa ticket ESC/POS por TCP 9100, con texto ASCII (acentos transliterados),
inicialización y corte. No se implementan etiquetas ZPL/TSPL ni selección automática de lenguaje.
**Probar conexión** abre y cierra TCP desde QZ en la PC; no imprime ni comprueba papel.
**Imprimir hoja de prueba** envía un ticket corto directo a la impresora, sin pasar por la cola.
No abrir el puerto 9100 de las impresoras a Internet.

## Verificación

- `npm run build` en el API y `npx tsc --noEmit` en el frontend.
- `npm test -- --runInBand` para pruebas del API.
- `npm run test:impresion` en el frontend verifica conexión compartida, prueba TCP sin
  papel, formato de comanda, firma y recuperación de errores con QZ simulado.
- `npm run test:impresion:sql` usa exclusivamente el PostgreSQL local temporal de pruebas
  en `127.0.0.1:55439`, usuario `pedidos_test`; no lee `.env` ni modifica la BD del restaurante.
- Validación física pendiente: conectar QZ y una impresora real, comandar desde otro
  dispositivo, probar reconexión y confirmar que cada estación recibe únicamente sus ítems.
