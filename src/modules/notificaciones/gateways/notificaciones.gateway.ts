import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
} from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { Request } from 'express';
import {
  JwtPayload,
  JwtStrategy,
} from '../../../common/strategies/jwt.strategy';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { canalesPermitidos } from '../constants/canales';

export interface NotificacionEmitida {
  id: string;
  canal: string;
  titulo: string;
  mensaje: string;
  severidad: string;
  ruta: string;
  idReferencia: number | null;
  creadaEn: string;
  leida: boolean;
}

interface ClienteInfo {
  user: AuthenticatedUser;
  canales: Set<string>;
}

@WebSocketGateway({
  namespace: '/notificaciones',
  transports: ['websocket'],
  cors: { origin: true, credentials: true },
})
export class NotificacionesGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(NotificacionesGateway.name);
  private readonly clients = new Map<Socket, ClienteInfo>();

  constructor(
    private readonly jwt: JwtService,
    private readonly auth: JwtStrategy,
  ) {}

  private async autorizar(socket: Socket): Promise<AuthenticatedUser> {
    const token: unknown = socket.handshake.auth?.token;
    if (typeof token !== 'string') throw new Error('Inicia sesión');
    const payload = await this.jwt.verifyAsync<JwtPayload>(token);
    const user = await this.auth.validate(
      { headers: { authorization: `Bearer ${token}` } } as Request,
      payload,
    );
    return user as unknown as AuthenticatedUser;
  }

  async handleConnection(socket: Socket) {
    try {
      const user = await this.autorizar(socket);
      if (!socket.connected) return;
      // Por defecto se recibe todo lo que el usuario puede ver.
      const permitidos = canalesPermitidos(user);
      this.clients.set(socket, { user, canales: new Set(permitidos) });

      // Permite al cliente reducir (nunca ampliar) los canales que escucha.
      socket.on('notificaciones:suscribir', (data: unknown, ack: unknown) => {
        const responder =
          typeof ack === 'function' ? (ack as (r: unknown) => void) : () => {};
        const raw = (data as { canales?: unknown })?.canales;
        if (!Array.isArray(raw)) {
          responder({ ok: false, message: 'Canales inválidos' });
          return;
        }
        const canales = canalesPermitidos(
          user,
          raw.filter((c): c is string => typeof c === 'string'),
        );
        const info = this.clients.get(socket);
        if (info) info.canales = new Set(canales);
        responder({ ok: true, canales });
      });

      socket.emit('notificacion:conectado', { canales: permitidos });
    } catch (error) {
      this.logger.warn(`WS rechazado: ${(error as Error)?.message ?? error}`);
      socket.emit('notificacion:error', 'Sesión inválida o sin permisos');
      socket.disconnect(true);
    }
  }

  handleDisconnect(socket: Socket) {
    this.clients.delete(socket);
  }

  /**
   * Con destinatarios, solo les llega a ellos; si no, a los suscritos al canal.
   */
  emitirNotificacion(notif: NotificacionEmitida, idsUsuario?: number[] | null) {
    const dirigida = Boolean(idsUsuario?.length);
    for (const [socket, info] of this.clients) {
      const llega = dirigida
        ? idsUsuario!.includes(info.user.id)
        : info.canales.has(notif.canal);
      if (llega) socket.emit('notificacion:nueva', notif);
    }
  }

  /** Sincroniza el estado de lectura entre las pestañas del mismo usuario. */
  notificarLeidas(idUsuario: number, ids: string[] | 'todas') {
    for (const [socket, info] of this.clients) {
      if (info.user.id === idUsuario)
        socket.emit('notificacion:leidas', { ids });
    }
  }
}
