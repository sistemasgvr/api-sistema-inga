import {
  ForbiddenException,
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { CrearNotificacionDto } from '../dto/crear-notificacion.dto';
import {
  ListarNotificacionesDto,
  MarcarTodasLeidasDto,
} from '../dto/listar-notificaciones.dto';
import { canalesPermitidos, DIAS_HISTORIAL } from '../constants/canales';
import {
  NotificacionesModel,
  NotificacionRow,
} from '../models/notificaciones.model';
import {
  NotificacionEmitida,
  NotificacionesGateway,
} from '../gateways/notificaciones.gateway';

/** Cada cuánto se envían los avisos generados en SQL (stock mínimo, recordatorios). */
const INTERVALO_DESPACHO_MS = 10_000;
/** Cada cuánto se generan recordatorios y se depura el historial. */
const INTERVALO_RECORDATORIOS_MS = 60 * 60 * 1000;

function aNotificacion(r: NotificacionRow): NotificacionEmitida {
  return {
    id: r.id,
    canal: r.canal,
    titulo: r.titulo,
    mensaje: r.mensaje,
    severidad: r.severidad,
    ruta: r.ruta,
    idReferencia: r.id_referencia === null ? null : Number(r.id_referencia),
    creadaEn: new Date(r.creada_en).toISOString(),
    leida: Boolean(r.leida),
  };
}

@Injectable()
export class NotificacionesLogic
  implements OnApplicationBootstrap, OnModuleDestroy
{
  private readonly logger = new Logger(NotificacionesLogic.name);
  private timers: NodeJS.Timeout[] = [];
  private despachando = false;
  private despachoPendiente = false;

  constructor(
    private readonly model: NotificacionesModel,
    private readonly gateway: NotificacionesGateway,
    private readonly config: ConfigService,
  ) {}

  onApplicationBootstrap() {
    if (this.config.get<string>('NOTIFICACIONES_DESPACHADOR') === 'false')
      return;
    this.timers.push(
      setInterval(() => void this.despachar(), INTERVALO_DESPACHO_MS),
      setInterval(
        () => void this.tareasPeriodicas(),
        INTERVALO_RECORDATORIOS_MS,
      ),
      // Primera pasada poco después de arrancar, sin demorar el inicio.
      setTimeout(() => void this.tareasPeriodicas(), 15_000),
    );
  }

  onModuleDestroy() {
    this.timers.forEach((t) => clearInterval(t));
    this.timers = [];
  }

  async emitir(dto: CrearNotificacionDto) {
    const severidad = dto.severidad ?? 'info';
    const creada = await this.model.crear({
      canal: dto.canal,
      titulo: dto.titulo,
      mensaje: dto.mensaje,
      severidad,
      ruta: dto.ruta,
      idReferencia: dto.idReferencia ?? null,
      idsUsuario: dto.idsUsuario,
    });
    if (!creada?.id) return null;
    const notif: NotificacionEmitida = {
      id: creada.id,
      canal: dto.canal,
      titulo: dto.titulo,
      mensaje: dto.mensaje,
      severidad,
      ruta: dto.ruta,
      idReferencia: dto.idReferencia ?? null,
      creadaEn: new Date(creada.creada_en ?? Date.now()).toISOString(),
      leida: false,
    };
    this.gateway.emitirNotificacion(notif, dto.idsUsuario);
    return notif;
  }

  /** Alta manual (pruebas o avisos del sistema): solo super administradores. */
  crearManual(dto: CrearNotificacionDto, user: AuthenticatedUser) {
    if (!user.es_super_admin)
      throw new ForbiddenException(
        'Solo un super administrador puede crear notificaciones',
      );
    return this.emitir(dto);
  }

  /**
   * Envía por socket los avisos que se generaron en la base de datos (outbox).
   * Se llama periódicamente y también justo después de operaciones que mueven
   * stock, para que la alerta llegue al instante.
   */
  async despachar() {
    if (this.despachando) {
      this.despachoPendiente = true;
      return;
    }
    this.despachando = true;
    try {
      do {
        this.despachoPendiente = false;
        const { registros = [] } = (await this.model.pendientesEmitir()) ?? {};
        for (const r of registros)
          this.gateway.emitirNotificacion(
            aNotificacion(r),
            r.ids_usuario_destino?.map(Number),
          );
      } while (this.despachoPendiente);
    } catch (error) {
      this.logger.error(
        'No se pudieron despachar notificaciones',
        error as Error,
      );
    } finally {
      this.despachando = false;
    }
  }

  /** Recordatorios (planilla, cajas abiertas) y limpieza del historial. */
  async tareasPeriodicas() {
    try {
      await this.model.generarRecordatorios();
      await this.model.depurar(DIAS_HISTORIAL);
    } catch (error) {
      this.logger.error(
        'Falló la tarea periódica de notificaciones',
        error as Error,
      );
    }
    await this.despachar();
  }

  async listarParaUsuario(
    user: AuthenticatedUser,
    filtros: ListarNotificacionesDto,
  ) {
    const result = await this.model.listar(
      user.id,
      canalesPermitidos(user),
      filtros,
    );
    return {
      registros: (result?.registros ?? []).map(aNotificacion),
      total: Number(result?.total ?? 0),
    };
  }

  async marcarLeida(id: string, user: AuthenticatedUser) {
    const result = await this.model.marcarLeida(id, user.id);
    this.gateway.notificarLeidas(user.id, [id]);
    return result;
  }

  async marcarTodasLeidas(user: AuthenticatedUser, dto: MarcarTodasLeidasDto) {
    const result = await this.model.marcarTodasLeidas(
      user.id,
      canalesPermitidos(user),
      dto.canal,
    );
    this.gateway.notificarLeidas(user.id, 'todas');
    return result;
  }

  async contarParaUsuario(user: AuthenticatedUser) {
    const result = await this.model.contarNoLeidas(
      user.id,
      canalesPermitidos(user),
    );
    return { total: Number(result?.total ?? 0) };
  }
}
