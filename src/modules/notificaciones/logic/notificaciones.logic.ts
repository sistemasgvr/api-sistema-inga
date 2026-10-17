import { Injectable } from '@nestjs/common';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { CrearNotificacionDto } from '../dto/crear-notificacion.dto';
import { NotificacionesModel } from '../models/notificaciones.model';
import { NotificacionesGateway } from '../gateways/notificaciones.gateway';

@Injectable()
export class NotificacionesLogic {
  constructor(
    private readonly model: NotificacionesModel,
    private readonly gateway: NotificacionesGateway,
  ) {}

  async emitir(dto: CrearNotificacionDto) {
    const id = await this.model.crear({
      canal: dto.canal,
      titulo: dto.titulo,
      mensaje: dto.mensaje,
      severidad: dto.severidad ?? 'info',
      ruta: dto.ruta,
      idReferencia: dto.idReferencia ?? null,
    });
    const notif = {
      id,
      canal: dto.canal,
      titulo: dto.titulo,
      mensaje: dto.mensaje,
      severidad: dto.severidad ?? 'info',
      ruta: dto.ruta,
      idReferencia: dto.idReferencia ?? null,
      creadaEn: new Date().toISOString(),
      leida: false,
    };
    this.gateway.emitirNotificacion(notif, dto.idsUsuario);
    return notif;
  }

  canalesPermitidos(user: AuthenticatedUser): string[] {
    return this.gateway.canalesPermitidosUsuario(user);
  }

  async listarParaUsuario(user: AuthenticatedUser) {
    const canales = this.canalesPermitidos(user);
    const result = await this.model.listar(user.id, canales);
    return (result.registros ?? []).map((r: any) => ({
      id: r.id,
      canal: r.canal,
      titulo: r.titulo,
      mensaje: r.mensaje,
      severidad: r.severidad,
      ruta: r.ruta,
      idReferencia: r.id_referencia,
      creadaEn: r.creada_en,
      leida: Boolean(r.leida),
    }));
  }

  async marcarLeida(id: string, user: AuthenticatedUser) {
    return this.model.marcarLeida(id, user.id);
  }

  async contarParaUsuario(user: AuthenticatedUser) {
    const canales = this.canalesPermitidos(user);
    const result = await this.model.contarNoLeidas(user.id, canales);
    return { total: result.total ?? 0 };
  }
}
