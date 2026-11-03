import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError, type AxiosInstance } from 'axios';
import type {
  ConsultaDni,
  ConsultaRuc,
} from './interfaces/apisperu-consultas.interface';
import { RUTAS_CONSULTAS_APISPERU } from './apisperu.constants';
import { ApisPeruFallo } from './apisperu.service';

@Injectable()
export class ApisPeruConsultasService {
  private readonly logger = new Logger(ApisPeruConsultasService.name);
  private readonly http: AxiosInstance;
  private readonly token: string | null;

  constructor(config: ConfigService) {
    const url = config
      .get<string>('APISPERU_CONSULTAS_URL')
      ?.trim()
      .replace(/\/+$/, '');
    this.token = config.get<string>('APISPERU_CONSULTAS_TOKEN')?.trim() || null;
    if (!url || !this.token)
      this.logger.warn(
        'Consulta DNI/RUC no configurada: defina APISPERU_CONSULTAS_URL y APISPERU_CONSULTAS_TOKEN en el .env',
      );
    this.http = axios.create({
      baseURL: url ? `${url}/` : undefined,
      timeout: config.get<number>('APISPERU_CONSULTAS_TIMEOUT_MS'),
    });
  }

  dni(numero: string) {
    return this.consultar<ConsultaDni>(RUTAS_CONSULTAS_APISPERU.dni, numero);
  }

  ruc(numero: string) {
    return this.consultar<ConsultaRuc>(RUTAS_CONSULTAS_APISPERU.ruc, numero);
  }

  private async consultar<T>(ruta: string, numero: string): Promise<T> {
    if (!this.http.defaults.baseURL || !this.token)
      throw new ApisPeruFallo(
        'La consulta de DNI/RUC no está configurada: defina APISPERU_CONSULTAS_URL y APISPERU_CONSULTAS_TOKEN en el .env del API',
        null,
        false,
      );
    try {
      const { data } = await this.http.get<
        T & { success?: boolean; message?: string }
      >(`${ruta}/${encodeURIComponent(numero)}`, {
        params: { token: this.token },
      });
      // Un documento inexistente responde 200 con success = false.
      if (!data || data.success === false)
        throw new ApisPeruFallo(
          data?.message || 'No se encontraron datos para ese documento',
          404,
          false,
        );
      return data;
    } catch (error) {
      if (error instanceof ApisPeruFallo) throw error;
      const e = error as AxiosError<{ message?: string }>;
      const status = e.response?.status ?? null;
      if (status === 401 || status === 403)
        throw new ApisPeruFallo(
          'APIsPERU rechazó el token de consultas: revise APISPERU_CONSULTAS_TOKEN',
          status,
          false,
        );
      const reintentable = status === null || status === 429 || status >= 500;
      // Solo ruta y estado: la URL completa lleva el token.
      if (reintentable)
        this.logger.warn(`Consulta ${ruta} no respondió (${status ?? e.code})`);
      throw new ApisPeruFallo(
        reintentable
          ? 'El servicio de consulta de DNI/RUC no respondió. Inténtalo nuevamente.'
          : `Consulta rechazada (${status}): ${e.response?.data?.message ?? 'sin detalle'}`,
        status,
        reintentable,
      );
    }
  }
}
