import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TipoComprobante } from '../constants/sunat';
import { diaLima } from '../helpers/documentos';
import { SunatComprobantesModel } from '../models/sunat-comprobantes.model';
import { SunatConfiguracionLogic } from './sunat-configuracion.logic';
import { SunatEmisionLogic } from './sunat-emision.logic';
import { SunatLotesLogic } from './sunat-lotes.logic';

/** Cada cuánto revisa vencimientos y tickets. */
const INTERVALO_MS = 5 * 60 * 1000;

/**
 * Tarea periódica de SUNAT:
 * 1. libera envíos individuales que quedaron colgados;
 * 2. consulta los tickets de resúmenes y bajas en proceso;
 * 3. envía lo que llegó a su fecha límite: facturas una por una y boletas en
 *    resumen diario (agrupadas por día de emisión);
 * 4. una vez al día avisa los pendientes que vencen hoy o mañana.
 * Se desactiva con SUNAT_PROGRAMADOR=false (p. ej. con varias instancias del API,
 * aunque las reservas en la base ya evitan envíos duplicados).
 */
@Injectable()
export class SunatProgramadorLogic
  implements OnApplicationBootstrap, OnModuleDestroy
{
  private readonly logger = new Logger(SunatProgramadorLogic.name);
  private timers: NodeJS.Timeout[] = [];
  private ejecutando = false;
  private ultimoAviso: string | null = null;

  constructor(
    private readonly config: ConfigService,
    private readonly configuracion: SunatConfiguracionLogic,
    private readonly comprobantes: SunatComprobantesModel,
    private readonly emision: SunatEmisionLogic,
    private readonly lotes: SunatLotesLogic,
  ) {}

  onApplicationBootstrap() {
    if (String(this.config.get('SUNAT_PROGRAMADOR')) === 'false') return;
    this.timers.push(
      setInterval(() => void this.ejecutar(), INTERVALO_MS),
      setTimeout(() => void this.ejecutar(), 30_000),
    );
  }

  onModuleDestroy() {
    this.timers.forEach((t) => clearInterval(t));
    this.timers = [];
  }

  async ejecutar() {
    if (this.ejecutando) return;
    this.ejecutando = true;
    try {
      if (!(await this.configuracion.lista())) return;
      const liberados = await this.comprobantes.liberarColgados();
      if (liberados)
        this.logger.warn(
          `${liberados} envíos SUNAT colgados volvieron a pendientes`,
        );
      await this.lotes.consultarPendientes();
      await this.enviarVencidos();
      await this.avisarPorVencer();
    } catch (error) {
      this.logger.error('Falló la tarea periódica de SUNAT', error as Error);
    } finally {
      this.ejecutando = false;
    }
  }

  private async enviarVencidos() {
    const vencidos = await this.comprobantes.vencidos();
    for (const f of vencidos.filter(
      (v) => v.tipoComprobante === TipoComprobante.FACTURA,
    )) {
      try {
        await this.emision.enviar(f.id, null);
      } catch (error) {
        this.logger.warn(
          `Factura ${f.id} no enviada: ${(error as Error).message}`,
        );
      }
    }
    const boletasPorDia = new Map<string, number[]>();
    for (const b of vencidos.filter(
      (v) => v.tipoComprobante === TipoComprobante.BOLETA,
    ))
      boletasPorDia.set(b.dia, [...(boletasPorDia.get(b.dia) ?? []), b.id]);
    for (const [dia, ids] of boletasPorDia) {
      try {
        await this.lotes.enviarBoletas(dia, ids, null);
      } catch (error) {
        this.logger.warn(
          `Resumen de boletas del ${dia} no enviado: ${(error as Error).message}`,
        );
      }
    }
  }

  private async avisarPorVencer() {
    const hoy = diaLima(new Date());
    if (this.ultimoAviso === hoy) return;
    const grupos = await this.comprobantes.porVencer();
    this.ultimoAviso = hoy;
    if (!grupos.length) return;
    const detalle = grupos
      .map(
        (g) =>
          `${g.cantidad} ${g.tipoComprobante === TipoComprobante.FACTURA ? 'factura(s)' : 'boleta(s)'} (vence ${g.vence})`,
      )
      .join(', ');
    await this.emision.avisar(
      null,
      'Comprobantes por enviar a SUNAT',
      `Pendientes que vencen hoy o mañana: ${detalle}. Se enviarán solos al vencer; puede enviarlos ahora desde Ventas.`,
      'warning',
    );
  }
}
