import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
} from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { randomUUID } from 'node:crypto';
import { Request } from 'express';
import {
  JwtPayload,
  JwtStrategy,
} from '../../../common/strategies/jwt.strategy';
import { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { CrearNotificacionDto } from '../dto/crear-notificacion.dto';

// Canal -> permiso requerido (null = cualquier autenticado).
const CANAL_PERMISO: Record<string, string | null> = {
  pedidos: 'pedidos.listar',
  cocina: 'pedidos.comandar',
  caja: 'cajas.ver',
  inventario: 'inventario.ver',
  ventas: 'ventas.listar',
  'cuentas-por-pagar': 'cxp.listar',
  'cuentas-por-cobrar': 'cxc.listar',
  gastos: 'gastos.listar',
  'gastos-diarios': 'gdo.listar',
  sistema: null,
};

const CANALES_VALIDOS = Object.keys(CANAL_PERMISO);

interface ClienteInfo {
  user: AuthenticatedUser;
  canales: Set<string>;
}

@WebSocketGateway({ namespace: '/notificaciones', transports: ['websocket'], cors: { origin: true, credentials: true } })
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

  private canalesPermitidos(user: AuthenticatedUser, canales: string[]) {
    return canales.filter((c) => {
      if (!CANALES_VALIDOS.includes(c)) return false;
      const permiso = CANAL_PERMISO[c];
      if (permiso === null) return true;
      if (user.es_super_admin) return true;
      return user.permisos.includes(permiso);
    });
  }

  canalesPermitidosUsuario(user: AuthenticatedUser): string[] {
    return this.canalesPermitidos(user, CANALES_VALIDOS);
  }

  async handleConnection(socket: Socket) {
    try {
      const user = await this.autorizar(socket);
      if (!socket.connected) return;
      const info = { user, canales: new Set(this.canalesPermitidos(user, CANALES_VALIDOS)) };
      this.clients.set(socket, info);

      socket.on('notificaciones:suscribir', (data: unknown, ack: unknown) => {
        if (typeof ack !== 'function') return;
        const responder = ack as (r: unknown) => void;
        const raw = (data as { canales?: unknown })?.canales;
        if (!Array.isArray(raw)) {
          responder({ ok: false, message: 'Canales inválidos' });
          return;
        }
        const permitidos = this.canalesPermitidos(
          user,
          raw.filter((c): c is string => typeof c === 'string'),
        );
        const info = this.clients.get(socket);
        if (info) {
          info.canales = new Set(permitidos);
        }
        responder({ ok: true, canales: permitidos });
      });

      socket.emit('notificacion:conectado', { canales: CANALES_VALIDOS });
    } catch (error) {
      this.logger.error('WS connection rejected', error as Error);
      socket.emit('notificacion:error', 'Sesión inválida o sin permisos');
      socket.disconnect(true);
    }
  }

  handleDisconnect(socket: Socket) {
    this.clients.delete(socket);
  }

  emitirNotificacion(notif: { id: string; canal: string; titulo: string; mensaje: string; severidad: string; ruta: string; idReferencia: number | null; creadaEn: string; leida: boolean }, idsUsuario?: number[]) {
    const canal = notif.canal;
    for (const [socket, info] of this.clients) {
      if (info.canales.has(canal)) {
        socket.emit('notificacion:nueva', notif);
      }
    }
    if (idsUsuario?.length) {
      for (const [socket, info] of this.clients) {
        if (idsUsuario.includes(info.user.id) && !info.canales.has(canal)) {
          socket.emit('notificacion:nueva', notif);
        }
      }
    }
  }

  notificarDisponible() {
    for (const socket of this.clients.keys()) socket.emit('notificacion:disponible');
  }
}
