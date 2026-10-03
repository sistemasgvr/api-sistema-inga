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
import { ImpresionLogic } from '../logic/impresion.logic';

// Se registran handlers con ack explícito para no aplicar filtros/interceptores HTTP a WS.
@WebSocketGateway({ namespace: '/impresion', transports: ['websocket'] })
export class ImpresionGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(ImpresionGateway.name);
  private readonly clients = new Set<Socket>();
  constructor(
    private readonly jwt: JwtService,
    private readonly auth: JwtStrategy,
    private readonly impresion: ImpresionLogic,
  ) {}

  private async autorizar(socket: Socket) {
    const token: unknown = socket.handshake.auth?.token;
    if (typeof token !== 'string')
      throw new Error('Inicia sesión para imprimir');
    const payload = await this.jwt.verifyAsync<JwtPayload>(token);
    const user = await this.auth.validate(
      { headers: { authorization: `Bearer ${token}` } } as Request,
      payload,
    );
    if (
      !user.es_super_admin &&
      (!user.permisos.includes('estaciones.listar') ||
        !user.permisos.includes('pedidos.comandar'))
    )
      throw new Error(
        'Se requieren permisos estaciones.listar y pedidos.comandar',
      );
  }

  async handleConnection(socket: Socket) {
    try {
      await this.autorizar(socket);
      if (!socket.connected) return;
      this.clients.add(socket);
      const propietario = randomUUID();
      let ocupado = false;
      socket.on('impresion:solicitar', (data: unknown, ack: unknown) => {
        if (typeof ack !== 'function') return;
        const responder = ack as (result: unknown) => void;
        if (ocupado) {
          responder({ ok: false, message: 'Solicitud en curso' });
          return;
        }
        ocupado = true;
        void (async () => {
          await this.autorizar(socket); // Revalida expiración, logout y permisos en cada operación.
          const estaciones = (data as { estaciones?: unknown })?.estaciones;
          if (
            !Array.isArray(estaciones) ||
            !estaciones.length ||
            estaciones.length > 100 ||
            !estaciones.every((id) => Number.isSafeInteger(id) && id > 0)
          )
            throw new Error('Estaciones inválidas');
          const trabajo = await this.impresion.tomar(
            estaciones as number[],
            propietario,
          );
          responder({ ok: true, trabajo, propietario });
        })()
          .catch((error: unknown) => {
            this.logger.warn(
              error instanceof Error ? error.message : 'Error de impresión',
            );
            responder({
              ok: false,
              message:
                'No se pudo obtener la cola. Revisa tu sesión, permisos y la migración de impresión.',
            });
          })
          .finally(() => {
            ocupado = false;
          });
      });
      socket.emit('impresion:listo');
    } catch {
      socket.emit(
        'impresion:error',
        'Sesión inválida o sin permisos de impresión',
      );
      socket.disconnect(true);
    }
  }

  handleDisconnect(socket: Socket) {
    this.clients.delete(socket);
  }

  notificar() {
    // Sólo una señal sin información del pedido; la entrega exige autenticación vigente.
    for (const socket of this.clients) socket.emit('impresion:disponible');
  }
}
