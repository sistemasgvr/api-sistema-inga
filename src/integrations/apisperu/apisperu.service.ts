import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError, type AxiosInstance } from 'axios';
import type {
  DocumentResponse,
  StatusResult,
  SummaryResponse,
  ValidacionApisPeru,
} from './interfaces/apisperu.interface';
import { RUTAS_APISPERU, type OperacionApisPeru } from './apisperu.constants';

/**
 * Error de comunicación con APIsPERU. `reintentable` indica que el comprobante no
 * llegó a SUNAT (red caída, 5xx, límite de peticiones): se puede volver a enviar igual.
 */
export class ApisPeruFallo extends Error {
  constructor(
    message: string,
    readonly status: number | null,
    readonly reintentable: boolean,
    readonly detalle?: unknown,
  ) {
    super(message);
    this.name = 'ApisPeruFallo';
  }
}

/**
 * Cliente HTTP de APIsPERU. La URL base del servicio sale de APISPERU_URL (.env);
 * las rutas de cada operación están en RUTAS_APISPERU. Cada empresa emite con su
 * propio token (no caduca); lo entrega quien llama, descifrado desde
 * gen_configuracion_sunat.
 */
@Injectable()
export class ApisPeruService {
  private readonly logger = new Logger(ApisPeruService.name);
  private readonly http: AxiosInstance;
  private readonly configurado: boolean;

  constructor(config: ConfigService) {
    const url = config.get<string>('APISPERU_URL')?.trim().replace(/\/+$/, '');
    this.configurado = Boolean(url);
    if (!url)
      this.logger.warn(
        'APIsPERU no configurado: defina APISPERU_URL en el .env',
      );
    this.http = axios.create({
      baseURL: url,
      timeout: config.get<number>('APISPERU_TIMEOUT_MS'),
    });
  }

  /** Ruta de la operación; sin APISPERU_URL no se llama a APIsPERU. */
  private ruta(operacion: OperacionApisPeru): string {
    if (!this.configurado)
      throw new ApisPeruFallo(
        'APIsPERU no está configurado: defina APISPERU_URL en el .env del API',
        null,
        false,
      );
    return RUTAS_APISPERU[operacion];
  }

  async enviarFactura(token: string, documento: object) {
    return this.post<DocumentResponse>(
      token,
      this.ruta('facturaEnvio'),
      documento,
    );
  }

  /** XML firmado sin enviarlo a SUNAT. */
  async xmlFactura(token: string, documento: object): Promise<string> {
    return this.post<string>(token, this.ruta('facturaXml'), documento, 'text');
  }

  /** Representación impresa en A4 que genera APIsPERU. */
  async pdfFactura(token: string, documento: object): Promise<Buffer> {
    const datos = await this.post<ArrayBuffer>(
      token,
      this.ruta('facturaPdf'),
      documento,
      'arraybuffer',
    );
    return Buffer.from(datos);
  }

  async estadoFactura(
    token: string,
    consulta: { tipo: string; serie: string; numero: string; ruc?: string },
  ) {
    return this.get<StatusResult>(token, this.ruta('facturaEstado'), consulta);
  }

  async enviarResumen(token: string, resumen: object) {
    return this.post<SummaryResponse>(
      token,
      this.ruta('resumenEnvio'),
      resumen,
    );
  }

  async estadoResumen(token: string, ticket: string) {
    return this.get<StatusResult>(token, this.ruta('resumenEstado'), {
      ticket,
    });
  }

  async enviarBaja(token: string, baja: object) {
    return this.post<SummaryResponse>(token, this.ruta('bajaEnvio'), baja);
  }

  async estadoBaja(token: string, ticket: string) {
    return this.get<StatusResult>(token, this.ruta('bajaEstado'), { ticket });
  }

  private async post<T>(
    token: string,
    ruta: string,
    cuerpo: object,
    responseType: 'json' | 'text' | 'arraybuffer' = 'json',
  ): Promise<T> {
    try {
      const { data } = await this.http.post<T>(ruta, cuerpo, {
        headers: { Authorization: `Bearer ${token}` },
        responseType,
      });
      return data;
    } catch (error) {
      throw this.fallo(error, ruta);
    }
  }

  private async get<T>(
    token: string,
    ruta: string,
    params: object,
  ): Promise<T> {
    try {
      const { data } = await this.http.get<T>(ruta, {
        headers: { Authorization: `Bearer ${token}` },
        params,
      });
      return data;
    } catch (error) {
      throw this.fallo(error, ruta);
    }
  }

  private fallo(error: unknown, ruta: string): ApisPeruFallo {
    const e = error as AxiosError;
    const status = e.response?.status ?? null;
    let datos: unknown = e.response?.data;
    // En el PDF A4 la respuesta de error también llega como binario.
    if (datos instanceof ArrayBuffer || Buffer.isBuffer(datos)) {
      try {
        datos = JSON.parse(Buffer.from(datos as ArrayBuffer).toString('utf8'));
      } catch {
        datos = undefined;
      }
    } else if (typeof datos === 'string') {
      try {
        datos = JSON.parse(datos);
      } catch {
        // Texto plano: se usa tal cual.
      }
    }
    if (status === 401 || status === 403)
      return new ApisPeruFallo(
        'APIsPERU rechazó el token de la empresa: revise el token en Configuración → Empresa → SUNAT',
        status,
        false,
        datos,
      );
    if (status === 400 && Array.isArray(datos)) {
      const mensajes = (datos as ValidacionApisPeru[])
        .map((v) => [v.field, v.message].filter(Boolean).join(': '))
        .filter(Boolean);
      return new ApisPeruFallo(
        `Datos rechazados por APIsPERU: ${mensajes.join('; ') || 'validación'}`,
        status,
        false,
        datos,
      );
    }
    const mensaje =
      (datos as { message?: string } | undefined)?.message ??
      (typeof datos === 'string' ? datos.slice(0, 300) : null) ??
      e.message;
    const reintentable = status === null || status === 429 || status >= 500;
    if (reintentable)
      this.logger.warn(
        `APIsPERU ${ruta} no respondió (${status ?? e.code}): ${mensaje}`,
      );
    return new ApisPeruFallo(
      reintentable
        ? `No se pudo comunicar con APIsPERU: ${mensaje}`
        : `APIsPERU respondió ${status}: ${mensaje}`,
      status,
      reintentable,
      datos,
    );
  }
}
