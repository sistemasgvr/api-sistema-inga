# Facturación electrónica SUNAT (APIsPERU)

Boletas y facturas se emiten a SUNAT mediante APIsPERU: el API arma el JSON y APIsPERU genera, firma y envía el XML. La nota de venta no se envía.

## Instalación

1. Ejecutar la migración (re-ejecutable):

   ```bash
   psql "$DATABASE_URL" -f database_sql/migraciones/20261028_sunat_apisperu.sql
   ```

2. Variables del `.env`:

   | Variable | Uso |
   |---|---|
   | `SUNAT_CRYPTO_KEY` | **Obligatoria** para guardar credenciales. Mínimo 32 caracteres. Cifra token, clave SOL y certificado (AES-256-GCM). Si cambia, hay que volver a registrar las credenciales. |
   | `APISPERU_URL` | **Obligatoria** para emitir. URL base del servicio de APIsPERU (no hay valor por defecto en el código). Las rutas de cada operación están en `src/integrations/apisperu/apisperu.constants.ts`. |
   | `APISPERU_TIMEOUT_MS` | Opcional. Predeterminado 60000. |
   | `SUNAT_PROGRAMADOR` | Opcional. `false` desactiva el envío automático y la consulta de tickets. |

3. Asignar los permisos `sunat.*` a los roles que correspondan.

## Configuración (vista Empresa)

1. Crear la empresa en la cuenta de APIsPERU (con su certificado, usuario SOL secundario y ambiente beta) y copiar su **token**.
2. `PUT /general/empresa`: RUC, razón social, dirección, **distrito** (`idDistrito`, buscar con `GET /general/empresa/distritos?buscar=`), nombre comercial y **tasa de IGV**.
3. `PUT /general/empresa/sunat`: `tokenEmision`, `idAmbiente` (1 beta, 2 producción), `usuarioSol`, `claveSol`, `diasLimiteEnvioBoleta` (3) y `diasLimiteEnvioFactura` (7). Los campos vacíos conservan el valor actual.
4. `POST /general/empresa/sunat/certificado` (multipart `file` + `clave`): valida el .pfx/.p12 y guarda el PEM cifrado, con titular y vencimiento.
5. `POST /general/empresa/sunat/probar`: pide a APIsPERU el XML de una boleta de prueba (no se envía a SUNAT).

`GET /general/empresa/sunat` nunca devuelve secretos: indica qué está cargado y `datosEmpresaFaltantes`.

## Flujo

- **Cobro**: se genera el número y se imprime el ticket con el QR de SUNAT. La boleta/factura queda **Pendiente** (`estado_sunat = 1`) con `fecha_limite_envio` = día de emisión + días configurados.
- **Envío manual**: `POST /sunat/comprobantes/:id/enviar` (individual) o `POST /sunat/resumen-dia/enviar` `{ fecha }` (facturas una por una y boletas en resumen diario de hasta 500).
- **Envío automático**: cada 5 minutos el programador envía lo que llegó a su fecha límite (facturas individuales; boletas en resumen diario agrupadas por día), consulta los tickets en proceso y avisa una vez al día lo que vence hoy o mañana.
- **Reemisión** (Ventas): si el comprobante anterior seguía pendiente, se anula sin ir a SUNAT; si ya estaba aceptado, el API envía su baja (factura: comunicación de baja RA; boleta: resumen con estado 3). Pasados 7 días se rechaza la reemisión: requiere nota de crédito (fase 2).
- **Cortesías** (líneas con importe 0) no se informan a SUNAT.

### Estados (`ven_comprobante.estado_sunat`)

| Valor | Estado | Significado |
|---|---|---|
| 0 | No aplica | Nota de venta |
| 1 | Pendiente | Aún no enviado, o SUNAT no lo procesó (excepción 0100–1999 / sin conexión): se reintenta |
| 2 | Aceptado | Con CDR (observaciones 4000+ en `observaciones_sunat`) |
| 3 | Rechazado | Código 2000–3999: el número queda usado, reemitir |
| 4 | Anulado | Baja aceptada, o anulado antes de enviarse |
| 5 | En proceso | Envío en curso o en un resumen diario esperando respuesta |

## Endpoints `/sunat`

| Método | Ruta | Permiso |
|---|---|---|
| GET | `/sunat/pendientes` | `sunat.listar` |
| GET | `/sunat/resumen-dia?fecha=` | `sunat.listar` |
| POST | `/sunat/resumen-dia/enviar` | `sunat.crear` |
| GET | `/sunat/comprobantes/:id` · `/historial` | `sunat.listar` |
| POST | `/sunat/comprobantes/:id/enviar` · `/consultar` | `sunat.crear` |
| POST | `/sunat/comprobantes/:id/baja` `{ motivo }` | `sunat.eliminar` |
| GET | `/sunat/comprobantes/:id/xml` · `/cdr` · `/pdf-a4` | `sunat.listar` |
| GET | `/sunat/lotes` · `/sunat/lotes/:id` · `/xml` · `/cdr` | `sunat.listar` |
| POST | `/sunat/lotes/:id/consultar` | `sunat.crear` |

Los archivos (XML, CDR, PDF A4, XML/CDR de lotes) se guardan en Supabase Storage bajo `sunat/<ruc>/…`. El XML de una boleta informada por resumen se genera con APIsPERU al descargarlo.
